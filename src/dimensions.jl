abstract type AbstractDimType end

abstract type Horizontal <: AbstractDimType end
abstract type Vertical <: AbstractDimType end
abstract type Other <: AbstractDimType end
const NonHorizontal = Union{Vertical, Other}

struct Lonlat <: Horizontal end 
struct NonDimensionCoords <: Horizontal end
struct NoCoords <: Horizontal end

abstract type AbstractDim{AbstractDimType} end

"""
    MessageDimension <: AbstractDim
One dimension found in the data part of the GRIB message. Typically, this is `lon` and `lat`
dimensions.
"""
struct MessageDimension{T} <: AbstractDim{T}
    name::String
    length::Int
end

"""
    IndexedDimension <: AbstractDim
Dimension created from reading the index values with the keys in the `COORDINATE_VARIABLES_KEYS` constant.
"""
struct IndexedDimension{T} <: AbstractDim{T}
    name::String
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

Base.keys(dims::Dimensions) = [d.name for d in dims]
Base.in(name::String, dims::Dimensions) = name in keys(dims)
Base.getindex(dims::Dimensions, name::String) = first(dims[keys(dims) .== name])

dimname(dim::AbstractDim) = dim.name

dimlength(dim::AbstractDim) = dim.length
dimlength(dim::Union{IndexedDimension, ArtificialDimension}) = length(dim.values)

_dimtype(dim::AbstractDim{T}) where T = T
_filter_on_dimtype(dims, type) = Tuple([dim for dim in dims if _dimtype(dim) == type])
_get_verticaldims(dims) = _filter_on_dimtype(dims, Vertical)
_get_horizontaldims(dims) = _filter_on_dimtype(dims, Horizontal)
_get_otherdims(dims) = _filter_on_dimtype(dims, Other)

function _horizontaltype(index::FileIndex)::Type{<:Horizontal}
    grid_type = getone(index, "gridType")
    if grid_type in GRID_TYPES_DIMENSION_COORDS
        Lonlat
    elseif grid_type in GRID_TYPES_2D_NON_DIMENSION_COORDS
        NonDimensionCoords
    else
        NoCoords
    end
end

function _alldims(index::FileIndex)
    dims = vcat(_horizdim(index, _horizontaltype(index))..., _verticaldims(index)..., _otherdims(index)...)
    NTuple{length(dims), AbstractDim}(dims)
end

function _otherdims(index::FileIndex; coord_keys = COORDINATE_VARIABLES_KEYS)
    dims = AbstractDim[]
    for key in coord_keys
        # For the moment, we only consider `valid_time` key for time dimension.
        # This should be extended in the future
        if haskey(index, key) && key ∉ IGNORED_COORDS
            push!(dims, _build_otherdims(key, index))
        end
    end
    Tuple(dims)
end

_build_otherdims(key, headers) = IndexedDimension{Other}(key, headers[key])

_verticaldims(index) = Tuple(_build_verticaldims(index))

function _build_verticaldims(index)
    dims = AbstractDim[]
    type_of_levels = index["typeOfLevel"]

    # We ignore those dimensions, since they imply a scalar coordinate variable
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
            dim = IndexedDimension{Vertical}(dimname, filtered_index["level"])
            push!(dims, dim)
        end
    end
    return dims
end

function _horizdim(index::FileIndex, ::Type{Lonlat})
    Tuple(MessageDimension{Horizontal}.(["lon", "lat"], [getone(index, "Nx"), getone(index, "Ny")]))
end

function _horizdim(index::FileIndex, ::Type{NonDimensionCoords})
    Tuple(MessageDimension{Horizontal}.(["x", "y"], [getone(index, "Nx"), getone(index, "Ny")]))
end

function _horizdim(index::FileIndex, ::Type{NoCoords})
    Tuple(MessageDimension{Other}("values", getone(index, "numberOfPoints")))
end

_size_dims(dims) = Tuple([dimlength(d) for d in dims])

function _dim_values(index::FileIndex, dim::MessageDimension{<:NonHorizontal})
    vals = index[dim.name]
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

function _dim_values(index::FileIndex, dim::MessageDimension{Horizontal})
    if dim.name == "lon"
        index._first_data[1][:, 1]
    elseif dim.name == "lat"
        index._first_data[2][1, :]
    elseif dim.name == "x"
        index._first_data[1]
    elseif dim.name == "y"
        index._first_data[2]
    end
end

_dim_values(index::FileIndex, dim::Union{<:ArtificialDimension, <:IndexedDimension}) = identity.(dim.values)

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

message_indice(index::FileIndex, mind::MessageIndex, dim::AbstractDim) = nothing

function message_indice(index::FileIndex, mind::MessageIndex, dim::IndexedDimension{<:Other})
    vals = _dim_values(index, dim)
    return findfirst(x -> x == mind[dimname(dim)], vals)
end

function message_indice(index::FileIndex, mind::MessageIndex, dim::AbstractDim{<:Vertical})
    vals = _dim_values(index, dim)
    !(dimname(dim) == mind["typeOfLevel"])  && (return nothing)
    return findfirst(x -> x == mind["level"], vals)
end

function message_indice(index::FileIndex, mind::MessageIndex, dim::ArtificialDimension{<:Vertical})
    vals = _dim_values(index, dim)
    !(dim.gribname == mind["typeOfLevel"])  && (return nothing)
    return findfirst(x -> x == mind["level"], vals)
end

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

Base.show(io::IO, mime::MIME"text/plain", dim::MessageDimension) = print(io, "$(dim.name) = $(dimlength(dim))")
function Base.show(io::IO, mime::MIME"text/plain", dims::Dimensions) 
    println(io, "Dimensions:")
    for dim in dims
        println(io, "\t $(dim.name) = $(dimlength(dim))")
    end
end