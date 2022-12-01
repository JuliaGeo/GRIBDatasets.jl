"""
    GRIBDataset{T, N}
Mapping of a GRIB file to a structure that follows the CF conventions.

It can be created with the path to the GRIB file:

```julia
ds = GRIBDataset(example_file);
```

The list of variables can be accessed:

```julia-repl
julia> keys(ds)
7-element Vector{String}:
 "longitude"
 "latitude"
 "number"
 "valid_time"
 "level"
 "z"
 "t"
```

We can then index any of the variables or dimensions:
```julia-repl
julia> z = ds["z"]
Variable `z` with dims:
Dimensions:
         longitude = 120
         latitude = 61
         number = 10
         valid_time = 4
         level = 2

julia> ds["number"] |> collect
10-element Vector{Int64}:
 0
 1
 2
 3
 4
 5
 6
 7
 8
 9
```

We can slice the variables along the dimensions:
```julia-repl
julia> z[1:4, 3:6, 1, 1:2, 1]
4×4×2 reshape(::Array{Union{Missing, Float64}, 5}, 4, 4, 2) with eltype Union{Missing, Float64}:
[:, :, 1] =
 51038.7  50873.7  50731.2  50824.5
 51058.0  50859.0  50656.2  50682.0
 51077.5  50838.5  50578.5  50541.2
 51095.0  50807.2  50490.5  50398.5

[:, :, 2] =
 51031.0  50822.3  50672.5  50773.0
 51067.5  50820.5  50582.8  50647.5
 51102.0  50816.0  50471.3  50526.0
 51133.3  50806.3  50351.3  50399.3
```
"""
struct GRIBDataset{T, N}
    index::FileIndex{T}
    dims::NTuple{N, Dimension}
    attrib::Dict{String, Any}
end

const Dataset = GRIBDataset

function GRIBDataset(index::FileIndex)
    GRIBDataset(index, _alldims(index), dataset_attributes(index)) 
end

GRIBDataset(filepath::AbstractString) = GRIBDataset(FileIndex(filepath))

Base.keys(ds::Dataset) = getvars(ds)
Base.haskey(ds::Dataset, key) = key in keys(ds)
Base.getindex(ds::Dataset, key) = Variable(ds, string(key))

getlayersid(ds::GRIBDataset) = ds.index["paramId"]
getlayersname(ds::GRIBDataset) = string.(ds.index["cfVarName"])

getvars(ds::GRIBDataset) = vcat(keys(ds.dims), getlayersname(ds))

_dim_values(ds::GRIBDataset, dim) = _dim_values(ds.index, dim)
# _dim_values(ds::GRIBDataset, dim::Dimension{Horizontal}) = _dim_values(ds.index, dim)


function Base.show(io::IO, mime::MIME"text/plain", ds::Dataset)
    println(io, "Dataset from file: $(ds.index.grib_path)")
    show(io, mime, ds.dims)
    println(io, "Layers:")
    println(io, join(getlayersname(ds), ", "))
    println(io, "with attributes:")
    show(io, mime, ds.attrib)
end

function dataset_attributes(index::FileIndex)
    attributes = Dict{String, Any}()
    attributes["Conventions"] = "CF-1.7"
    attributes["source"] = index.grib_path
    # if haskey(index, "centreDescription") 
    #     attributes["institution"] = index["centreDescription"]
    # end

    # Originally, CfGRIB was forcing the keys GLOBAL_ATTRIBUTES_KEYS to have
    # only one values in the dataset. It appeared to me that it was too restrictive
    # so we just join the different values
    for key in GLOBAL_ATTRIBUTES_KEYS
        if haskey(index, key) 
            attributes[key] = join(index[key], ", ")
        end
    end
    return attributes
end
