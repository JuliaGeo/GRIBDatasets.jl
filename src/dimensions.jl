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
    Dimension{OtherDim}("values", getone(index, "numberOfPoints")) 
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
    vals
end

function _dim_values(index::FileIndex, dim::Dimension{Geography})
    if dim.name in ["longitude", "x"]
        index._first_data[1][:, 1]
    elseif dim.name in ["latitude", "y"]
        index._first_data[2][1, :]
    end
end

Base.show(io::IO, mime::MIME"text/plain", dim::Dimension) = print(io, "$(dim.name) = $(dim.length)")
function Base.show(io::IO, mime::MIME"text/plain", dims::Tuple{Vararg{<:Dimension}}) 
    println(io, "Dimensions:")
    for dim in dims
        println(io, "\t $(dim.name) = $(dim.length)")
    end
end