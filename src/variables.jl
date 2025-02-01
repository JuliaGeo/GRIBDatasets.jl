abstract type AbstractGRIBVariable{T, N} <: AbstractVariable{T, N} end

"""
    DiskValues{T, N, M} <: DA.AbstractDiskArray{T, N}

Object that maps the dimensions lookup to GRIB messages offsets.
`message_dims` are the dimensions that are found in the GRIB message (namely longitudes and latitudes).
`other_dims` are the dimensions that have been infered from reading the GRIB file index.

# Example
```julia-repl
julia> dv.other_dims
Dimensions:
         number = 10
         valid_time = 4
         level = 2

julia> size(dv.offsets)
(10, 4, 2)
julia> dv.message_dims
Dimensions:
         longitude = 120
         latitude = 61
```
"""
struct DiskValues{T, N, M} <: DA.AbstractDiskArray{T, N}
    "Reference to the dataset"
    ds::GRIBDataset
    "FileIndex filtered according to the current variable"
    layer_index::FileIndex{T}
    "Maps the non-message dimensions to the message offset"
    offsets::Array{Int, M}
    message_dims::Dimensions
    other_dims::Dimensions
end

"""
    DiskValues(layer_index::FileIndex{T}, dims::Dimensions) where T
Create a `DiskValues` object from matching the GRIB messages headers in `layer_index` to
the dimensions values in `dims`.
"""
function DiskValues(ds::GRIBDataset, layer_index::FileIndex{T}, dims::Dimensions) where T
    messagedims = Tuple([dim for dim in dims if dim isa MessageDimension])
    otherdims = Tuple([dim for dim in dims if !(dim isa MessageDimension)])
    N = length(dims)
    M = length(otherdims)
    offsets_array = Array{Int, M}(undef, _size_dims(otherdims))
    all_indices = messages_indices(layer_index, dims)

    for (mind, indices) in zip(layer_index.messages, all_indices)
        offsets_array[indices...] = getoffset(mind)
    end
    DiskValues{T, N, M}(ds, layer_index, offsets_array, messagedims, otherdims)
end

Base.size(dv::DiskValues) = (_size_dims(dv.message_dims)..., _size_dims(dv.other_dims)...)

# Since some dimensions (typically the horizontal lon/lat dimensions) are encoded in the message data,
# we have to threat them separately from the other dimensions (typically time, number, vertical...). This is
# what makes this code quite complicated. There's probably a clever/prettier way of doing this, but this one works for now...
function DA.readblock!(A::DiskValues, aout, i::AbstractUnitRange...)
    general_index = A.ds.index
    grib_path = general_index.grib_path

    message_dim_inds = i[1:length(A.message_dims)]
    headers_dim_inds = i[length(A.message_dims) + 1: end]
    
    all_messages_offset = general_index._all_offsets
    missing_value = getone(general_index, "missingValue")

    rebased_range = Tuple([1:length(range) for range in headers_dim_inds])
    rebased_message_dim = Tuple([1:length(range) for range in message_dim_inds])

    file = GribFile(grib_path)
    # GribFile(grib_path) do file
        for (I, Ir) in zip(CartesianIndices(headers_dim_inds), CartesianIndices(rebased_range))
            offset = A.offsets[I]
            message_index = findfirst(all_messages_offset .>= offset)
            if isnothing(message_index)
                error("Couldn't find a message that corresponds to indices $(Tuple(I))")
            end
            message_index = message_index - 1
            seek(file, message_index)
            message = Message(file)
            values = message["values"][message_dim_inds...]
            # aout[rebased_message_dim..., Tuple(Ir)...] = replace(values, missing_value => missing)
            aout[rebased_message_dim..., Tuple(Ir)...] = values
        end
    # end
    destroy(file)
end

DA.eachchunk(A::DiskValues) = DA.GridChunks(A, size(A))
DA.haschunks(A::DiskValues) = DA.Chunked() # Its basically one large chunk

"""
    Variable <: AbstractArray
Variable of a dataset `ds`. It can be a layer or a dimension. In case of a layer, the values are lazily loaded when it's sliced.
"""
struct Variable{T, N, TA <: Union{Array{T, N}, DA.AbstractDiskArray{T, N}}, TP} <: AbstractGRIBVariable{T,N}
    ds::TP
    name::String
    dims::NTuple{N, AbstractDim}
    values::TA
    attrib::Dict{String, Any}
end
Base.parent(var::Variable) = var.values
Base.size(var::Variable) = _size_dims(var.dims)  

ndims(::AbstractGRIBVariable{T,N}) where {T,N} = N
varname(var::Variable) = var.name
dims(var::Variable) = var.dims

missing_value(var::Variable) = parent(var) isa DiskValues ? missing_value(parent(var).layer_index) : nothing
### Implementation of CommonDataModel
name(var::AbstractGRIBVariable) = varname(var)
CDM.dim(var::AbstractGRIBVariable, dimname::String) = dimlength(_get_dim(var, dimname))
dimnames(var::AbstractGRIBVariable) = keys(dims(var))
CDM.variable(ds::GRIBDataset, variablename::AbstractString) = Variable(ds, variablename)

attribnames(var::AbstractGRIBVariable) = keys(var.attrib)
attrib(var::AbstractGRIBVariable, attribname::String) = var.attrib[attribname]

dataset(var::AbstractGRIBVariable) = var.ds

_get_dim(var::Variable, key::String) = _get_dim(var.dims, key)

DA.@implement_diskarray Variable
# Avoid DiskArrays.jl indexing when the parent is an Array
Base.getindex(var::Variable{T,N,Array{T,N}}, I...) where {T,N} = 
    getindex(parent(var), I...)

function DA.readblock!(A::Variable, aout, i::AbstractUnitRange...)
    @show i
    DA.readblock!(parent(A), aout, i...)
end
DA.eachchunk(A::Variable) = DA.eachchunk(parent(A))
DA.haschunks(A::Variable) = DA.haschunks(parent(A))

function Variable(ds::GRIBDataset, key)
    dsdims = ds.dims
    if key in dsdims
        dim = dsdims[key]
        # dim = _get_dim(ds, key)
        Variable(ds, dim)
    elseif key in getlayersname(ds)
        layer_index = filter_messages(ds.index, cfVarName = key)
        
        levels = [mind["typeOfLevel"] for mind in layer_index.messages]
        unique_levels = unique(levels)
        if length(unique_levels) !== 1
            examples = ["GRIBDataset(\"$(path(ds))\", filter_by_values=Dict(\"typeOfLevel\" => \"$(level)\"))\n" for level in unique_levels]
            error("""
            The variable `$key` is defined on multiple types of vertical levels. This is not supported by GRIBDatasets.
            To overcome this issue, you can try to filter the GRIB file on some specific level. In your case, try to re-open the dataset with one of:
            $(join(examples))
            """)
        end

        dims = _alldims(layer_index)

        # A little bit tricky... If the variable is related to an artificial dimension,
        # we identify the dimension and replace it in the reconstructed `dims`.
        if any(_is_in_artificial.(key, dsdims))
            artdim = filter(x -> _is_in_artificial(key, x), dsdims)
            length(artdim) > 1 && error("More than one artificial for this variable. Not supported.")
            dims = _replace_with_artificial(artdim[1], dims)
        end

        for d in dims
            if !_is_length_consistent(d, dsdims)
                @warn "The length of dimension $(dimname(d)) in variable $key is different from the corresponding dimension in the dataset. This could lead to unexpected behaviour."
            end
        end

        dv = DiskValues(ds, layer_index, dims)
        attributes = layer_attributes(layer_index)
        Variable(ds, string(key), dims, dv, attributes)
    elseif key in additional_coordinates_varnames(ds.dims)
        values = key == "longitude" ? ds.index._first_data[1] : ds.index._first_data[2]

        Variable(ds, key, _filter_horizontal_dims(ds.dims), values, coordinate_attributes(key))
    else
        error("The key `$key` was not found in the dataset. Available keys: $(keys(ds))")
    end
end

function Variable(ds::GRIBDataset, dim::AbstractDim) 
    vals = _dim_values(ds, dim)
    attributes = coordinate_attributes(dim)
    Variable(ds, dim.name, (dim,), vals, attributes)
end

function layer_attributes(index::FileIndex)
    attributes = Dict{String, Any}()
    data_var_attrs_keys = DATA_ATTRIBUTES_KEYS
    data_var_attrs_keys = [
        data_var_attrs_keys;
        get(GRID_TYPE_MAP, getone(index, "gridType"), [])
    ]

    for key in data_var_attrs_keys
        if haskey(index, key) 
            attributes[key] = join(index[key], ", ")
        end
    end
    attributes
end

function coordinate_attributes(key)
    attributes = Dict{String, Any}()
    merge!(attributes, copy(get(COORD_ATTRS, key, Dict())))
    attributes
end

coordinate_attributes(dim::AbstractDim) = coordinate_attributes(dimgribname(dim))

# Shifts the responsibility of showing the variable in the REPL to CommonDataModel
Base.show(io::IO, mime::MIME"text/plain", var::AbstractGRIBVariable) = show(io, var)
