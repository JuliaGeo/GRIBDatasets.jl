function stamp_grib_attributes(grib_attributes)
    Dict([
        "GRIB_" * string(k) => v for (k, v) in grib_attributes
    ])
end