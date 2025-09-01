const IGNORED_COORDS = [
    # The valid_time coordinate need to be re-constructed from the "time" and "step" coordinates
    "valid_time",
    "verifying_time",
    "indexing_time",
]

const GLOBAL_ATTRIBUTES_KEYS = [
    "edition", "centre",
    "centreDescription", "subCentre"
]

const DATA_ATTRIBUTES_KEYS = [
    "paramId",
    "shortName",
    "units",
    "name",
    "cfName",
    "cfVarName",
    "dataType",
    "missingValue",
    "numberOfPoints",
    "totalNumber",
    "numberOfDirections",
    "numberOfFrequencies",
    "typeOfLevel",
    "NV",
    "stepUnits",
    "stepType",
    "gridType",
    "gridDefinitionDescription",
]

const GRID_TYPE_MAP = Dict(
    "regular_ll" => [
        "Nx",
        "iDirectionIncrementInDegrees",
        "iScansNegatively",
        "longitudeOfFirstGridPointInDegrees",
        "longitudeOfLastGridPointInDegrees",
        "Ny",
        "jDirectionIncrementInDegrees",
        "jPointsAreConsecutive",
        "jScansPositively",
        "latitudeOfFirstGridPointInDegrees",
        "latitudeOfLastGridPointInDegrees",
    ],
    "rotated_ll" => [
        "Nx",
        "Ny",
        "angleOfRotationInDegrees",
        "iDirectionIncrementInDegrees",
        "iScansNegatively",
        "jDirectionIncrementInDegrees",
        "jPointsAreConsecutive",
        "jScansPositively",
        "latitudeOfFirstGridPointInDegrees",
        "latitudeOfLastGridPointInDegrees",
        "latitudeOfSouthernPoleInDegrees",
        "longitudeOfFirstGridPointInDegrees",
        "longitudeOfLastGridPointInDegrees",
        "longitudeOfSouthernPoleInDegrees",
    ],
    "reduced_ll" => [
        "Ny",
        "jDirectionIncrementInDegrees",
        "jPointsAreConsecutive",
        "jScansPositively",
        "latitudeOfFirstGridPointInDegrees",
        "latitudeOfLastGridPointInDegrees",
    ],
    "regular_gg" => [
        "Nx",
        "iDirectionIncrementInDegrees",
        "iScansNegatively",
        "longitudeOfFirstGridPointInDegrees",
        "longitudeOfLastGridPointInDegrees",
        "N",
        "Ny",
    ],
    "rotated_gg" => [
        "Nx",
        "Ny",
        "angleOfRotationInDegrees",
        "iDirectionIncrementInDegrees",
        "iScansNegatively",
        "jPointsAreConsecutive",
        "jScansPositively",
        "latitudeOfFirstGridPointInDegrees",
        "latitudeOfLastGridPointInDegrees",
        "latitudeOfSouthernPoleInDegrees",
        "longitudeOfFirstGridPointInDegrees",
        "longitudeOfLastGridPointInDegrees",
        "longitudeOfSouthernPoleInDegrees",
        "N",
    ],
    "lambert" => [
        "LaDInDegrees",
        "LoVInDegrees",
        "iScansNegatively",
        "jPointsAreConsecutive",
        "jScansPositively",
        "latitudeOfFirstGridPointInDegrees",
        "latitudeOfSouthernPoleInDegrees",
        "longitudeOfFirstGridPointInDegrees",
        "longitudeOfSouthernPoleInDegrees",
        "DyInMetres",
        "DxInMetres",
        "Latin2InDegrees",
        "Latin1InDegrees",
        "Ny",
        "Nx",
    ],
    "reduced_gg" => ["N", "pl"],
    "sh" => ["M", "K", "J"],
)

const GRID_TYPE_KEYS = unique(vcat(values(GRID_TYPE_MAP)...))

const ENSEMBLE_KEYS = ["number"]

const VERTICAL_KEYS = ["level"]

const DATA_TIME_KEYS = ["dataDate", "dataTime", "endStep"]

const ALL_REF_TIME_KEYS = [
    "time", "step",
    "valid_time", "verifying_time", "indexing_time",
    "forecastMonth"
]

const SPECTRA_KEYS = ["directionNumber", "frequencyNumber"]

const ALL_HEADER_DIMS = vcat(
    ENSEMBLE_KEYS,
    VERTICAL_KEYS,
    DATA_TIME_KEYS,
    ALL_REF_TIME_KEYS,
    SPECTRA_KEYS
)

const ALL_KEYS = sort(unique(vcat(
    GLOBAL_ATTRIBUTES_KEYS, DATA_ATTRIBUTES_KEYS,
    GRID_TYPE_KEYS, ALL_HEADER_DIMS
)))

const COORD_ATTRS = Dict(
    # geography
    "latitude"             => Dict(
        "units"            => "degrees_north",
        "standard_name"    => "latitude",
        "long_name"        => "latitude"
    ),
    "longitude"            => Dict(
        "units"            => "degrees_east",
        "standard_name"    => "longitude",
        "long_name"        => "longitude"
    ),
    # vertical
    "depthBelowLand"       => Dict(
        "units"            => "m",
        "positive"         => "down",
        "long_name"        => "soil depth",
        "standard_name"    => "depth",
    ),
    "depthBelowLandLayer"  => Dict(
        "units"            => "m",
        "positive"         => "down",
        "long_name"        => "soil depth",
        "standard_name"    => "depth",
    ),
    "hybrid"               => Dict(
        "units"            => "1",
        "positive"         => "down",
        "long_name"        => "hybrid level",
        "standard_name"    => "atmosphere_hybrid_sigma_pressure_coordinate",
    ),
    "heightAboveGround"    => Dict(
        "units"            => "m",
        "positive"         => "up",
        "long_name"        => "height above the surface",
        "standard_name"    => "height",
        "axis"             => "Z"
    ),
    "isobaricInhPa"        => Dict(
        "units"            => "hPa",
        "positive"         => "down",
        "stored_direction" => "decreasing",
        "standard_name"    => "air_pressure",
        "long_name"        => "pressure",
        "axis"             => "Z",
    ),
    "isobaricInPa"         => Dict(
        "units"            => "Pa",
        "positive"         => "down",
        "stored_direction" => "decreasing",
        "standard_name"    => "air_pressure",
        "long_name"        => "pressure",
        "axis"             => "Z",
    ),
    "isobaricLayer"        => Dict(
        "units"            => "Pa",
        "positive"         => "down",
        "standard_name"    => "air_pressure",
        "long_name"        => "pressure",
    ),
    # ensemble
    "number"               => Dict(
        "units"            => "1",
        "standard_name"    => "realization",
        "long_name"        => "ensemble member numerical id",
    ),
    # time
    "step"                 => Dict(
        "units"            => "hours",
        "standard_name"    => "forecast_period",
        "long_name"        => "time since forecast_reference_time",
    ),
    "time"                 => Dict(
        "units"            => "seconds since 1970-01-01T00:00:00",
        "calendar"         => "proleptic_gregorian",
        "standard_name"    => "forecast_reference_time",
        "long_name"        => "initial time of forecast",
    ),
    "indexing_time"        => Dict(
        "units"            => "seconds since 1970-01-01T00:00:00",
        "calendar"         => "proleptic_gregorian",
        "standard_name"    => "forecast_reference_time",
        "long_name"        => "nominal initial time of forecast",
    ),
    "valid_time"           => Dict(
        "units"            => "seconds since 1970-01-01T00:00:00",
        "calendar"         => "proleptic_gregorian",
        "standard_name"    => "time",
        "long_name"        => "time",
    ),
    "verifying_time"       => Dict(
        "units"            => "seconds since 1970-01-01T00:00:00",
        "calendar"         => "proleptic_gregorian",
        "standard_name"    => "time",
        "long_name"        => "time",
    ),
)

const GRID_TYPES_DIMENSION_COORDS = ["regular_ll", "regular_gg"]

const GRID_TYPES_2D_NON_DIMENSION_COORDS = [
    "rotated_ll",
    "rotated_gg",
    "lambert",
    "albers",
    "polar_stereographic",
]

const COORDINATE_VARIABLES_KEYS = vcat(keys(COORD_ATTRS) |> collect)

const CF_MAP_ATTRIBUTES = Dict(
    "cfName" => "standard_name",
    "name" => "long_name",
    "units" => "units"
)

const KEYS_TO_SQUEEZE = ["number"]
# """
#     GRIB_KEY_TO_DIMNAMES_MAP
# Maps the GRIB keys to the name the variable will have in the GRIBDataset.
# This follows (as much as possible) the names used when converting GRIB files
# to netCDF with the `cdo` software (https://code.mpimet.mpg.de/projects/cdo/).
# """
# const GRIB_KEY_TO_DIMNAMES_MAP = Dict(
#     "longitude"         => "lon",
#     "latitude"          => "lat",
#     "heightAboveGround" => "height",
#     "hybrid"            => "lev",
#     "isobaricInhPa"     => "plev",
#     "isobaricInPa"      => "plev",
#     "valid_time"        => "time"
# )