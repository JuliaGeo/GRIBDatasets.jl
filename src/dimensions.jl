abstract type AbstractDimType end

abstract type Horizontal <: AbstractDimType end
abstract type Vertical <: AbstractDimType end
abstract type Other <: AbstractDimType end
const NonHorizontal = Union{Vertical, Other}

"""
    RegularGrid <: Horizontal
Represent regular grid types (typically regular_ll and regular_gg).
The typical messages data is a 2-D matrix.
"""
struct RegularGrid <: Horizontal end

"""
    NonRegularGrid <: Horizontal
Represent non-regular grid types.
The typical messages data is a 2-D matrix.
"""
struct NonRegularGrid <: Horizontal end

"""
    OtherGrid <: Horizontal
Represent non-regular grid types, where the typical messages data is a 1-D vector.
"""
struct OtherGrid <: Horizontal end

abstract type AbstractDim{AbstractDimType} end

"""
    MessageDimension <: AbstractDim
One dimension found in the data part of the GRIB message. Typically, this is `lon` and `lat`
dimensions.
"""
struct MessageDimension{T} <: AbstractDim{T}
    name::String
    gribname::String
    length::Int
end

"""
    IndexedDimension <: AbstractDim
Dimension created from reading the index values with the keys in the `COORDINATE_VARIABLES_KEYS` constant.
"""
struct IndexedDimension{T} <: AbstractDim{T}
    name::String
    gribname::String
    values::Vector{Any}
end

"""
    ArtificialDimension <: AbstractDim
This type needs to be used when it is needed to create an artificial dimension.
Typically this happens when some variables are defined on a similar type of level, but not on
the same level values. For example, u10 and t2 are both defined on `heightAboveGround`, but
the first is only defined at 10m and the second at 2m. In that case a `height` and a 
`height_2` level will be created.
"""
struct ArtificialDimension{T} <: AbstractDim{T}
    name::String
    gribname::String
    values::Vector{Any}
    related_variables::Vector{<:String}
end

const Dimensions = Tuple{AbstractDim, Vararg{AbstractDim}}

# Base.keys(dims::Dimensions) = [k for (k, v) in dims]
Base.keys(dims::Dimensions) = [dimname(dim) for dim in dims]
Base.in(name::String, dims::Dimensions) = name in keys(dims)
Base.getindex(dims::Dimensions, name::String)::AbstractDim = _get_dim(dims, name)
# Base.iterate(dims::Dimensions) = iterate(map(dim -> dim.name => dim.length, dims))
# Base.iterate(dims::Dimensions, i::Int64) = iterate(map(dim -> dim.name => dim.length, dims), i)
Base.pairs(dims::Dimensions) = map(dim -> dimname(dim) => dimlength(dim), dims)

dimname(dim::AbstractDim) = dim.name
dimgribname(dim::AbstractDim) = dim.gribname

dimlength(dim::AbstractDim) = dim.length
dimlength(dim::Union{IndexedDimension, ArtificialDimension}) = length(dim.values)

_dimtype(dim::AbstractDim{T}) where T = T
_filter_on_dimtype(dims, type) = Tuple([dim for dim in dims if _dimtype(dim) == type])
_get_verticaldims(dims) = _filter_on_dimtype(dims, Vertical)
_get_horizontaldims(dims) = _filter_on_dimtype(dims, Horizontal)
_get_otherdims(dims) = _filter_on_dimtype(dims, Other)

_size_dims(dims) = Tuple([dimlength(d) for d in dims])

function _get_dim(dims, dname)::AbstractDim 
    fdim = dims[keys(dims) .== dname]
    fdim == () && throw(KeyError(dname))
    return first(fdim)
end

function _horizontal_gridtype(index::FileIndex)::Type{<:Horizontal}
    grid_type = getone(index, "gridType")

    # NOTE: `GRID_TYPES_DIMENSION_COORDS` and `GRID_TYPES_2D_NON_DIMENSION_COORDS` are legacy constant definitions from
    # the python cfgrib package (https://github.com/ecmwf/cfgrib). It seems that they discriminate between regular
    # and non-regular grid, unlike their name suggests.
    if grid_type in GRID_TYPES_DIMENSION_COORDS
        RegularGrid
    elseif grid_type in GRID_TYPES_2D_NON_DIMENSION_COORDS
        NonRegularGrid
    else
        OtherGrid
    end
end

function _alldims(index::FileIndex)
    dims = vcat(_horizdims(index, _horizontal_gridtype(index))..., _verticaldims(index)..., _otherdims(index)...)
    NTuple{length(dims), AbstractDim}(dims)
end

function _otherdims(index::FileIndex; coord_keys = COORDINATE_VARIABLES_KEYS)
    dims = AbstractDim[]
    for key in coord_keys
        # For the moment, we only consider `valid_time` key for time dimension.
        # This should be extended in the future
        if haskey(index, key) && key ∉ IGNORED_COORDS
            newdim = _build_otherdims(key, index)
            if !(dimlength(newdim) == 1 && dimgribname(newdim) in KEYS_TO_SQUEEZE)
                push!(dims, newdim)
            end
        end
    end
    Tuple(dims)
end

_build_otherdims(key, headers) = IndexedDimension{Other}(key, key, headers[key])

_verticaldims(index) = Tuple(_build_verticaldims(index))

function _build_verticaldims(index)
    dims = AbstractDim[]
    type_of_levels = index["typeOfLevel"]

    # Typically, type of levels like surface and meanSea are ignored
    type_of_levels = filter(x -> x ∈ COORDINATE_VARIABLES_KEYS, type_of_levels)

    # This checks if for some level types, some variables are defined on distinct level values.
    # If so, it creates an artificial dimension for each of the distinct values.
    for leveltype in type_of_levels
        dimname = _map_dimname(leveltype)
        filtered_index = filter_messages(index, typeOfLevel = leveltype)
        distinct = _separate_distinct_levels(filtered_index)
        if length(distinct) > 1
            for (i, (dimvalues, varnames)) in enumerate(distinct)
                distinct_dimname = _distinct_dimname(dimname, i)
                dim = ArtificialDimension{Vertical}(distinct_dimname, dimname, dimvalues, varnames)
                push!(dims, dim)

            end
        else
            dim = IndexedDimension{Vertical}(dimname, dimname, filtered_index["level"])
            push!(dims, dim)
        end
    end
    return dims
end

function _horizdims(index::FileIndex, ::Type{RegularGrid})
    Tuple(MessageDimension{RegularGrid}.(["lon", "lat"], ["longitude", "latitude"],[getone(index, "Nx"), getone(index, "Ny")]))
end

function _horizdims(index::FileIndex, ::Type{NonRegularGrid})
    Tuple(MessageDimension{NonRegularGrid}.(["x", "y"], ["x", "y"],[getone(index, "Nx"), getone(index, "Ny")]))
end

function _horizdims(index::FileIndex, ::Type{OtherGrid})
    Tuple([MessageDimension{OtherGrid}("values", "values", getone(index, "numberOfPoints"))])
end

function _dim_values(index::FileIndex, dim::MessageDimension{<:NonHorizontal})
    vals = index[dimgribname(dim)]
    # Convert time dimension to DateTime
    # if occursin("time", dim.name)
    #     vals = Dates.Second.(vals) .+ DEFAULT_EPOCH
    # end
    # It can happen that dimension values are not unique, especially in
    # GRIB file with duplicate valid times. I don't know how to handle such case. 
    if length(unique(vals)) !== length(vals)
        error("The values of dimension $(dim.name) are not unique.")
    end
    # identity is used to automatically convert from Any to Int or Float
    identity.(vals)
end

function _dim_values(index::FileIndex, dim::Union{MessageDimension{RegularGrid}})
    if dimgribname(dim) == "longitude"
        index._first_data[1][:, 1]
    elseif dimgribname(dim) == "latitude"
        index._first_data[2][1, :]
    # elseif dimgribname(dim) == "x"
    #     index._first_data[1]
    # elseif dimgribname(dim) == "y"
    #     index._first_data[2]
    end
end

_dim_values(index::FileIndex, dim::Union{MessageDimension{OtherGrid}, MessageDimension{NonRegularGrid}}) = nothing

_dim_values(::FileIndex, dim::Union{<:ArtificialDimension, <:IndexedDimension}) = _dim_values(dim)
_dim_values(dim::Union{<:ArtificialDimension, <:IndexedDimension}) = identity.(dim.values)

_has_coordinates(index::FileIndex, dim::AbstractDim) = !isnothing(_dim_values(index, dim))

_filter_horizontal_dims(dims::Dimensions) = Tuple(x for x in dims if x isa MessageDimension{<:Horizontal})

"""
    additional_coordinates_varnames(dims::Dimensions)
In case of irregular grids, eccodes might provide the longitude and latitude. If so, this will
then be stored as additionnal variables.
Additionnally the "valid_time" coordinates is reconstructed from the "time" and "step" dimensions.
"""
function additional_coordinates_varnames(dims::Dimensions)::Vector{<:AbstractString}
    dimtypes = _dimtype.(dims)
    additonal_coords = String[]
    if any(x -> x == NonRegularGrid || x == OtherGrid, dimtypes)
        push!(additonal_coords, ["longitude", "latitude"]...)
    end
    push!(additonal_coords, "valid_time")
    return additonal_coords
end
# _map_dimname(dimname) = get(GRIB_KEY_TO_DIMNAMES_MAP, dimname, dimname)
_map_dimname(dimname) = dimname

function _separate_distinct_levels(levindex::FileIndex; tocheck = "level")
    vals = get_values_from_filtered(levindex, "cfVarName", tocheck)
    res = DefaultDict{Any, Vector{String}}(() -> Vector{String}())

    for (k, v) in vals
        push!(res[v], k)
    end

    return res
end

_distinct_dimname(dimname, i) = i == 1 ? dimname : "$(dimname)_$i"

_is_in_artificial(varname, dim::AbstractDim) = false
_is_in_artificial(varname, dim::ArtificialDimension) = varname in dim.related_variables

function _replace_with_artificial(artificialdim, dims)
    map(dims) do dim
        if dimname(dim) == artificialdim.gribname
            artificialdim
        else
            dim
        end
    end
end

function _is_length_consistent(dim, dims)
    indims = dims[dimname(dim)]
    return dimlength(indims) == dimlength(dim) ? true : false
end

message_indice(index::FileIndex, mind::MessageIndex, dim::AbstractDim) = nothing

function message_indice(index::FileIndex, mind::MessageIndex, dim::IndexedDimension{<:Other})
    vals = _dim_values(index, dim)
    return findfirst(x -> x == mind[dimname(dim)], vals)
end

function message_indice(index::FileIndex, mind::MessageIndex, dim::AbstractDim{<:Vertical})
    vals = _dim_values(index, dim)
    !(dimgribname(dim) == mind["typeOfLevel"])  && (return nothing)
    return findfirst(x -> x == mind["level"], vals)
end

# function message_indice(index::FileIndex, mind::MessageIndex, dim::ArtificialDimension{<:Vertical})
#     vals = _dim_values(index, dim)
#     !(dimgribname(dim) == mind["typeOfLevel"])  && (return nothing)
#     return findfirst(x -> x == mind["level"], vals)
# end

function message_indices(index::FileIndex, mind::MessageIndex, dims::Dimensions)
    indices = Int[]
    for dim in dims
        ind = message_indice(index, mind, dim)
        !isnothing(ind) && (push!(indices, ind))
    end
    indices
end

"""
    message_indices(index::FileIndex, mind::MessageIndex, dims::Dimensions)
Find at which indices in `dims` correspond each GRIB message in `index`.
"""
messages_indices(index::FileIndex, dims::Dimensions) = [message_indices(index, mind, dims) for mind in index.messages]

Base.show(io::IO, mime::MIME"text/plain", dims::Dimensions) = show_dim(io, pairs(dims))