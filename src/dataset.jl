

const GRIBIterable = Union{AbstractDim}
Base.length(a::GRIBIterable) = length(keys(a))


struct GRIBDataset
    index::FileIndex
    dims::Dimensions
end

const Dataset = GRIBDataset

function GRIBDataset(index::FileIndex)
    GRIBDataset(index, _alldims(index), ) 
end

Base.keys(ds) = getvars(ds)