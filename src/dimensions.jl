abstract type AbstractDim end

abstract type AbstractDimType end

abstract type Horizontal <: AbstractDimType end
abstract type Vertical <: AbstractDimType end
abstract type Other <: AbstractDimType end
const NonHorizontal = Union{Vertical, Other}

struct Lonlat <: Horizontal end 
struct NonDimensionCoords <: Horizontal end
struct NoCoords <: Horizontal end

struct Dimension{T<:AbstractDimType} <: AbstractDim
    name::String
    length::Int
end

const TupleDims = Tuple{AbstractDim, Vararg{AbstractDim}}

struct Dimensions
    index::FileIndex
end

getdims(dims::Dimensions) = _alldims(dims.index)
Base.keys(dims::Dimensions) = [dim.name for dim in getdims(dims)]
Base.in(name::String, dims::Dimensions) = name in keys(dims)
Base.getindex(dims::Dimensions, name::String) = first(dims[keys(dims) .== name])
Base.getindex(dims::Dimensions, args...) = getindex(getdims(dims), args...)

from_message(dims::Dimensions)::TupleDims = Tuple([dim for dim in getdims(dims) if dim isa Dimension{<:Horizontal}])
from_index(dims::Dimensions)::TupleDims = Tuple([dim for dim in getdims(dims) if dim isa Dimension{<:NonHorizontal}])


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
    dims = vcat(_horizdim(index, _horizontaltype(index)), _otherdims(index))
    NTuple{length(dims), Dimension}(dims)
end

function _otherdims(index::FileIndex; coord_keys = vcat(keys(COORD_ATTRS) |> collect, "typeOfLevel"))
    dims = Dimension[]
    for key in coord_keys
        # For the moment, we only consider `valid_time` key for time dimension.
        # This should be extended in the future
        if haskey(index, key) && key ∉ IGNORED_COORDS
            push!(dims, _build_otherdims(key, index))
        end
    end
    dims
end

function _build_otherdims(key, headers)
    if key == "typeOfLevel"
        Dimension{Vertical}("level", length(headers["level"]))
    else
        Dimension{Other}(key, length(headers[key]))
    end
end

function _horizdim(index::FileIndex, ::Type{Lonlat})
    Dimension{Horizontal}.(["longitude", "latitude"], [getone(index, "Nx"), getone(index, "Ny")])
end

function _horizdim(index::FileIndex, ::Type{NonDimensionCoords})
    Dimension{Horizontal}.(["x", "y"], [getone(index, "Nx"), getone(index, "Ny")])
end

function _horizdim(index::FileIndex, ::Type{NoCoords})
    Dimension{Other}("values", getone(index, "numberOfPoints")) 
end

_size_dims(dims) = Tuple([d.length for d in dims])

function _dim_values(index::FileIndex, dim::Dimension{<:NonHorizontal})
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

function _dim_values(index::FileIndex, dim::Dimension{Horizontal})
    if dim.name == "longitude"
        index._first_data[1][:, 1]
    elseif dim.name == "latitude"
        index._first_data[2][1, :]
    elseif dim.name == "x"
        index._first_data[1]
    elseif dim.name == "y"
        index._first_data[2]
    end
end

Base.show(io::IO, mime::MIME"text/plain", dim::Dimension) = print(io, "$(dim.name) = $(dim.length)")
function Base.show(io::IO, mime::MIME"text/plain", dims::Tuple{Vararg{<:Dimension}}) 
    println(io, "Dimensions:")
    for dim in dims
        println(io, "\t $(dim.name) = $(dim.length)")
    end
end