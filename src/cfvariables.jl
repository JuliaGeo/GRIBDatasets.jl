
struct CFVariable{T, N, AT, TSA} <: AbstractGRIBVariable{T,N}
    var::Variable{T, N, AT}
    attrib::Dict{String, Any}
    _storage_attrib::TSA
end

function CFVariable(ds, varname; _v = Variable(ds, varname))
    v = _v
    missing_val = missing_value(v)
    T = eltype(v)
    N = ndims(v)

    storage_attrib = (
        missing_value = missing_val,
    )

    CFVariable{T, N, typeof(parent(v)), typeof(storage_attrib)}(_v, _v.attrib, storage_attrib)
end

Base.parent(cfvar::CFVariable) = parent(cfvar.var)
Base.size(cfvar::CFVariable) = size(cfvar.var)
Base.getindex(cfvar::CFVariable, I...) = getindex(parent(cfvar), I...)

function Base.getindex(cfvar::CFVariable{T, N, TV}, I...) where {T,N,TV <: DA.AbstractDiskArray{T, N}}
    A = getindex(parent(cfvar), I...)
    misval = cfvar._storage_attrib.missing_value

    isnothing(misval) && (return A)

    # return any(x -> x == misval, A) ? replace(A, misval => missing) : A
    return any(A .== misval) ? replace(A, misval => missing) : A

end

varname(cfvar::CFVariable) = varname(cfvar.var)
dims(cfvar::CFVariable) = dims(cfvar.var)

_get_dim(cfvar::CFVariable, dimname) = _get_dim(cfvar.var, dimname)

