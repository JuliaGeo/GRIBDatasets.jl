

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

Base.keys(ds) = getvars(ds)


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
