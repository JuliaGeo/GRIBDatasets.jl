function encode_cf_first(
    data_var_attrs::AbstractDict,
    encode_cf::Tuple{Vararg{String}}=("parameter", "time"),
    time_dims::Tuple{Vararg{String}}=("time", "step"),
)::Vector{String}
    #  NOTE: marking value as `const` just means it cannot be reassigned, the
    #  value can still be mutated/appended to, so be careful `append!`ing to
    #  the constants
    coords_map = deepcopy(CfGRIB.ENSEMBLE_KEYS)
    param_id = get(data_var_attrs, "GRIB_paramId", missing)
    data_var_attrs["long_name"] = "original GRIB paramId: $(param_id)"
    data_var_attrs["units"] = "1"

    if "parameter" in encode_cf
        if haskey(data_var_attrs, "GRIB_cfName")
            data_var_attrs["standard_name"] = data_var_attrs["GRIB_cfName"]
        end

        if haskey(data_var_attrs, "GRIB_name")
            data_var_attrs["long_name"] = data_var_attrs["GRIB_name"]
        end

        if haskey(data_var_attrs, "GRIB_units")
            data_var_attrs["units"] = data_var_attrs["GRIB_units"]
        end
    end

    if "time" in encode_cf
        if issubset(time_dims, CfGRIB.ALL_REF_TIME_KEYS)
            append!(coords_map, time_dims)
        else
            throw(
                "time_dims $(time_dims) is not a subset of " *
                "$(CfGRIB.ALL_REF_TIME_KEYS)",
            )
        end
    else
        append!(coords_map, CfGRIB.DATA_TIME_KEYS)
    end

    append!(coords_map, CfGRIB.VERTICAL_KEYS)
    append!(coords_map, CfGRIB.SPECTRA_KEYS)

    return coords_map
end


function enforce_unique_attributes(
    header_values::AbstractDict,
    attribute_keys::Vector{<:AbstractString},
)
    attributes = map(attribute_keys) do key 
        values = header_values[key]
        if length(values) > 1
            error("Attributes are not unique for " * "$key: $(values)")
        end

        value = first(values)

        if value ∉ ["undef", "unknown"]
            "GRIB_" * key => value
        end
    end
    
    Dict(attributes)
end


function build_dataset_attributes(
    header_values::AbstractDict,
    encoding::Dict{String,Any}
)
    attributes = enforce_unique_attributes(header_values, GLOBAL_ATTRIBUTES_KEYS)
    attributes["Conventions"] = "CF-1.7"

    if "GRIB_centreDescription" in keys(attributes)
        attributes["institution"] = attributes["GRIB_centreDescription"]
    end

    attributes_namespace = Dict(
        "cfgrib_version" => cfgrib_jl_version,  # TODO: Package versions are experimental, this should be changed: https://julialang.github.io/Pkg.jl/dev/api/#Pkg.dependencies
        "cfgrib_open_kwargs" => JSON.json(encoding),
        "eccodes_version" => "missing",  # TODO: Not sure how to get this
        "timestamp" => string(Dates.now()),
    )

    history_in = (
        "timestamp GRIB to CDM+CF via " *
        "cfgrib-cfgrib_version/ecCodes-eccodes_version with cfgrib_open_kwargs"
    )

    #  TODO: Fix quotes, should probably still be double quotes not single
    history_in = replace(history_in, "\"" => "'")
    attributes["history"] = history_in

    return attributes
end