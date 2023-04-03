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
struct DiskValues{T, N, M} <: DA.AbstractDiskArray{Union{Missing, T}, N}
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
    otherdims = Tuple([dim for dim in dims if dim isa Dimension{<:NonHorizontal}])
    horizdims = Tuple([dim for dim in dims if dim isa Dimension{<:Horizontal}])
    # otherdims = _otherdims(layer_index)
    # horizdims = _horizdim(layer_index, _horizontaltype(layer_index))
    N = length(dims)
    M = length(otherdims)
    offsets_array = Array{Int, M}(undef, _size_dims(otherdims))
    all_indices = messages_indices(layer_index, dims)

    for (mind, indices) in zip(layer_index.messages, all_indices)
        offsets_array[indices...] = getoffset(mind)
    end
    DiskValues{T, N, M}(ds, layer_index, offsets_array, horizdims, otherdims)
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
    
    all_message_lengths = get_messages_length(A.ds.index)
    all_message_cumsum = cumsum(all_message_lengths)
    missing_value = getone(general_index, "missingValue")

    rebased_range = Tuple([1:length(range) for range in headers_dim_inds])
    rebased_message_dim = Tuple([1:length(range) for range in message_dim_inds])

    file = GribFile(grib_path)
    # GribFile(grib_path) do file
        for (I, Ir) in zip(CartesianIndices(headers_dim_inds), CartesianIndices(rebased_range))
            offset = A.offsets[I]
            message_index = findfirst(all_message_cumsum .> offset)
            if isnothing(message_index)
                error("Couldn't find a message that corresponds to indices $(Tuple(I))")
            end
            message_index = message_index - 1
            seek(file, message_index)
            message = Message(file)
            values = message["values"][message_dim_inds...]
            aout[rebased_message_dim..., Tuple(Ir)...] = replace(values, missing_value => missing)
        end
    # end
    destroy(file)
end

DA.eachchunk(A::DiskValues) = DA.GridChunks(A, size(A))
DA.haschunks(A::DiskValues) = DA.Unchunked()

function message_indices(index::FileIndex, mind::MessageIndex, dims::Dimensions)
    indices = Int[]
    for dim in dims
        if dim isa Dimension{<:NonHorizontal}
            vals = _dim_values(index, dim)
            ind = findfirst(x -> x == mind[dim.name], vals)
            push!(indices, ind)
        end
    end
    indices
end

"""
    message_indices(index::FileIndex, mind::MessageIndex, dims::Dimensions)
Find at which indices in `dims` correspond each GRIB message in `index`.
"""
messages_indices(index::FileIndex, dims::Dimensions) = [message_indices(index, mind, dims) for mind in index.messages]

"""
    Variable <: AbstractArray
Variable of a dataset `ds`. It can be a layer or a dimension. In case of a layer, the values are lazily loaded when it's sliced.
"""
struct Variable{T, N, AT <: Union{Array{T, N}, DA.AbstractDiskArray{T, N}}} <: AbstractVariable{T,N}
    ds::GRIBDataset
    name::String
    dim::NTuple{N, Dimension}
    values::AT
    attrib::Dict{String, Any}
end
Base.parent(var::Variable) = var.values
Base.size(var::Variable) = _size_dims(var.dim)
Base.getindex(var::Variable, I...) = getindex(parent(var), I...)
name(var::Variable) = var.name
dimnames(var::Variable) = keys(var.dim)

function Variable(ds::GRIBDataset, key)
    if key in ds.dim
        dim = _get_dim(ds, key)
        Variable(ds, dim)
    elseif key in getlayersname(ds)
        layer_index = filter_messages(ds.index, cfVarName = key)
        dims = _alldims(layer_index)
        dv = DiskValues(ds, layer_index, dims)
        attributes = layer_attributes(layer_index)
        Variable(ds, string(key), dims, dv, attributes)
    else
        error("key $key not found in dataset")
    end
end

function Variable(ds::GRIBDataset, dim::Dimension) 
    vals = _dim_values(ds, dim)
    attributes = dim_attributes(dim)
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

function dim_attributes(dim)
    attributes = Dict{String, Any}()
    merge!(attributes, copy(get(COORD_ATTRS, dim.name, Dict())))
    attributes
end

# Shifts the responsibility of showing the variable in the REPL to CommonDataModel
Base.show(io::IO, mime::MIME"text/plain", var::Variable) = show(io, var)


# function Base.show(io::IO, var::Variable)
#     show(io, var.values)
# end