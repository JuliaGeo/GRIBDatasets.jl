

const GRIBIterable = Union{AbstractDim}
Base.length(a::GRIBIterable) = length(keys(a))


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
Base.getindex(ds::Dataset, key) = Variable(ds, string(key))

_dim_values(ds::GRIBDataset, dim::Dimension{<:NonHorizontal}) = _dim_values(ds.index, dim)
_dim_values(ds::GRIBDataset, dim::Dimension{Geography}) = _dim_values(ds.index, dim)


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
    # if haskey(index, "centreDescription") 
    #     attributes["institution"] = index["centreDescription"]
    # end

    # Originally, CfGRIB was forcing the keys GLOBAL_ATTRIBUTES_KEYS to have
    # only one values in the dataset. It appeared to me that it was too restrictive
    # so we just join the different values
    for key in GLOBAL_ATTRIBUTES_KEYS
        if haskey(index, key) 
            attributes[key] = join(index[key])
        end
    end
    return attributes
end
