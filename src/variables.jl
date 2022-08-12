getlayersid(ds::GRIBDataset) = ds.index["paramId"]
getlayersname(ds::GRIBDataset) = ds.index["cfVarName"]

getvars(ds::GRIBDataset) = vcat(keys(ds.dims), getlayersname(ds))

struct DiskValues{T, N} <: DA.AbstractDiskArray{T, N}
    offsets::Array{Int, N}
end
function DiskValues(layer_index::FileIndex{T}, ldims::Dimensions) where T
    offsets_array = Array{Int, length(ldims)}
    for m in layer_index.messages

    end
    for dim in ldims
        if dim isa Dimension{<:OtherDim}
            push!(offsets_vec, get_offsets.(Ref(layer_index.messages), dim.name, _dim_values(layer_index, dim))...)
        end
    end
end

function messages_indices(index::FileIndex, m::MessageIndex, dims::Dimensions)
    indices = Int[]
    for dim in dims
        if dim isa Dimension{<:OtherDim}
            vals = _dim_values(index, dim)
            ind = findfirst(x -> x == m[dim.name], vals)
            push!(indices, ind)
        end
    end
    indices
end

struct Variable{T, N, AT <: Union{Array{T, N}, DA.AbstractDiskArray{T, N}}} <: AbstractArray{T, N}
    ds::GRIBDataset
    name::String
    dims::NTuple{N, <: Dimension}
    values::AT
end
Base.parent(var::Variable) = var.values
Base.size(var::Variable) = Tuple([d.length for d in var.dims])
Base.getindex(var::Variable, I...) = getindex(parent(var), I...)

function Variable(ds::GRIBDataset, key)
    if key in ds.dims
        dim = ds.dims[key]
        Variable(ds, dim)
    elseif key in getlayersname(ds)
        layer_index = filter_messages(ds.index, cfVarName = key)
        dims = _alldims(layer_index)

    else
        error("key $key not found in dataset")
    end
end

function Variable(ds::GRIBDataset, dim::Dimension) 
    vals = _dim_values(ds, dim)
    Variable(ds, dim.name, (dim,), vals)
end

function _dim_values(index::FileIndex, dim::Dimension{OtherDim})
    sort(index[dim.name])
end
_dim_values(ds::GRIBDataset, dim::Dimension{OtherDim}) = _dim_values(ds.index, dim)

function _dim_values(index::FileIndex, dim::Dimension{Geography})
    if dim.name in ["longitude", "x"]
        index._first_data[1][:, 1]
    elseif dim.name in ["latitude", "y"]
        index._first_data[2][1, :]
    end
end
_dim_values(ds::GRIBDataset, dim::Dimension{Geography}) = _dim_values(ds.index, dim)

function Base.show(io::IO, mime::MIME"text/plain", var::Variable)
    println(io, "Variable with dims:")
    show(io, mime, var.dims)
end