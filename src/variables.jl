
getlayersid(ds::GRIBDataset) = ds.index["paramId"]
getlayersname(ds::GRIBDataset) = ds.index["cfVarName"]

getvars(ds::GRIBDataset) = vcat(keys(ds.dims), getlayersname(ds))

struct Variable{T, N, AT <: Union{Array{T, N}, DA.AbstractDiskArray}} <: AbstractArray{T, N}
    ds::GRIBDataset
    name::String
    dims::NTuple{N, <: Dimension}
    values::AT
end
Base.parent(var::Variable) = var.values
Base.size(var::Variable) = size(parent(var))
Base.getindex(var::Variable, I...) = getindex(parent(var), I...)

function Variable(ds::GRIBDataset, key)
    if key in ds.dims
        dim = ds.dims[key]
        Variable(ds, dim)
    elseif key in getlayersname(ds)
        layer_messages = filter_messages(ds.index, cfVarName = key)
    else
        error("key $key not found in dataset")
    end
end

function Variable(ds::GRIBDataset, dim::Dimension) 
    vals = _dim_values(ds, dim)
    Variable(ds, dim.name, (dim,), vals)
end


function _dim_values(ds::GRIBDataset, dim::Dimension{OtherDim})
    sort(ds.index[dim.name])
end

function _dim_values(ds::GRIBDataset, dim::Dimension{Geography})
    index = ds.index
    if dim.name in ["longitude", "x"]
        index._first_data[1][:, 1]
    elseif dim.name in ["latitude", "y"]
        index._first_data[2][1, :]
    end
end

function Base.show(io::IO, mime::MIME"text/plain", var::Variable)
    println(io, "Variable with dims:")
    show(io, mime, var.dims)
end