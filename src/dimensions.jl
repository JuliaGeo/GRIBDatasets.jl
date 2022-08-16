abstract type AbstractDim end

abstract type AbstractDimType end

abstract type Geography <: AbstractDimType end
abstract type Vertical <: AbstractDimType end
abstract type OtherDim <: AbstractDimType end
const NonHorizontal = Union{Vertical, OtherDim}

struct DimensionCoords <: Geography end 
struct NonDimensionCoords <: Geography end
struct NoCoords <: Geography end

struct Dimension{T<:AbstractDimType} <: AbstractDim
    name::String
    length::Int
end

const Dimensions = Tuple{Vararg{<:Dimension}}

Base.keys(dims::Dimensions) = [d.name for d in dims]
Base.in(name::String, dims::Dimensions) = name in keys(dims)
Base.getindex(dims::Dimensions, name::String) = first(dims[keys(dims) .== name])

function _geography(index::FileIndex)::Type{<:Geography}
    grid_type = getone(index, "gridType")
    if grid_type in GRID_TYPES_DIMENSION_COORDS
        DimensionCoords
    elseif grid_type in GRID_TYPES_2D_NON_DIMENSION_COORDS
        NonDimensionCoords
    else
        NoCoords
    end
end

function _alldims(index::FileIndex)
    dims = vcat(_geodims(index, _geography(index)), _otherdims(index))
    NTuple{length(dims), Dimension}(dims)
end

function _otherdims(index::FileIndex; coord_keys = vcat(keys(COORD_ATTRS) |> collect, "typeOfLevel"))
    [_detect_vertical(key, index) for key in coord_keys if haskey(index, key)]
end

function _detect_vertical(key, headers)
    if key == "typeOfLevel"
        Dimension{Vertical}("level", length(headers["level"]))
    else
        Dimension{OtherDim}(key, length(headers[key]))
    end
end

function _geodims(index::FileIndex, ::Type{DimensionCoords})
    Dimension{Geography}.(["longitude", "latitude"], [getone(index, "Nx"), getone(index, "Ny")])
end

function _geodims(index::FileIndex, ::Type{NonDimensionCoords})
    # Dict(
    #     "x" => getone(index, "Nx"),
    #     "y" => getone(index, "Ny"),
    # )
    Dimension{Geography}.(["x", "y"], [getone(index, "Nx"), getone(index, "Ny")])
end

function _geodims(index::FileIndex, ::Type{NoCoords})
    Dimension("values", getone(index, "numberOfPoints")) 
end

_size_dims(dims) = Tuple([d.length for d in dims])

Base.show(io::IO, mime::MIME"text/plain", dim::Dimension) = print(io, "$(dim.name) = $(dim.length)")
function Base.show(io::IO, mime::MIME"text/plain", dims::Tuple{Vararg{<:Dimension}}) 
    println(io, "Dimensions:")
    for dim in dims
        println(io, "\t $(dim.name) = $(dim.length)")
    end
end