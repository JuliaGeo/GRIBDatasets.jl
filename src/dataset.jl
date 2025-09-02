"""
    GRIBDataset{T, N}
Mapping of a GRIB file to a structure that follows the CF conventions.

It can be created with the path to the GRIB file:

```julia
ds = GRIBDataset(example_file);
```
"""
struct GRIBDataset{T, N, Tmaskingvalue} <: AbstractDataset
    index::FileIndex{T}
    dims::NTuple{N, AbstractDim}
    attrib::Dict{String, Any}
    maskingvalue::Tmaskingvalue
end

const Dataset = GRIBDataset

function GRIBDataset(index::FileIndex; maskingvalue = missing)
    GRIBDataset(index, _alldims(index), dataset_attributes(index), maskingvalue)
end

GRIBDataset(filepath::AbstractString; filter_by_values = Dict(), kwargs...) =
    GRIBDataset(FileIndex(filepath; filter_by_values); kwargs...)

Base.keys(ds::Dataset) = getvars(ds)
Base.haskey(ds::Dataset, key) = key in keys(ds)
Base.getindex(ds::Dataset, key::Union{Symbol,AbstractString}) = cfvariable(ds, string(key))

getlayersid(ds::GRIBDataset) = ds.index["paramId"]
getlayersname(ds::GRIBDataset) = string.(ds.index["cfVarName"])

function getvars(ds::GRIBDataset) 
    dimension_vars = keys(filter(x -> _has_coordinates(ds.index, x), ds.dims))
    layers_vars = getlayersname(ds)
    coordinates_vars = additional_coordinates_varnames(ds.dims)
    vcat(dimension_vars, layers_vars, coordinates_vars)
end

_dim_values(ds::GRIBDataset, dim) = _dim_values(ds.index, dim)
_get_dim(ds::GRIBDataset, key) = _get_dim(ds.dims, key)

### Implementation of CommonDataModel
path(ds::GRIBDataset) = ds.index.grib_path
CDM.dim(ds::GRIBDataset, dimname::String) = dimlength(_get_dim(ds.dims, dimname))
dimnames(ds::GRIBDataset) = keys(ds.dims)

attribnames(ds::GRIBDataset) = keys(ds.attrib)
attrib(ds::GRIBDataset, attribname::String) = ds.attrib[attribname]
maskingvalue(ds::GRIBDataset) = ds.maskingvalue

# _dim_values(ds::GRIBDataset, dim::Dimension{Horizontal}) = _dim_values(ds.index, dim)


# function Base.show(io::IO, mime::MIME"text/plain", ds::Dataset)
#     println(io, "Dataset from file: $(ds.index.grib_path)")
#     show(io, mime, ds.dim)
#     println(io, "Layers:")
#     println(io, join(getlayersname(ds), ", "))
#     println(io, "with attributes:")
#     show(io, mime, ds.attrib)
# end

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
