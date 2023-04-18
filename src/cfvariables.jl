
_get_dim(cfvar::CFVariable, dimname) = _get_dim(cfvar.var, dimname)
function cfvariable(ds, varname)
    v = Variable(ds, string(varname))
    misval = missing_value(v)
    CDM.cfvariable(
        ds, varname;
        _v = v,
        missing_value = isnothing(misval) ? eltype(v)[] : [misval],
        attrib = cflayer_attributes(v),
    )
end

# In case of layer variable
cflayer_attributes(var::Variable{T, N, <: DA.AbstractDiskArray{T, N}}) where {T, N} = cflayer_attributes(parent(var).layer_index)

# In case of a coordinate variable
cflayer_attributes(var::Variable) = var.attrib

function cflayer_attributes(index::FileIndex)
    attributes = Dict{String, Any}()

    for (gribkey, cfkey) in CF_MAP_ATTRIBUTES
        if haskey(index, gribkey) && !occursin("unknown", getone(index, gribkey))
            attributes[cfkey] = join(index[gribkey], ", ")
        end
    end

    return attributes
end
