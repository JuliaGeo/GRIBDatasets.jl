## Indexing the GRIB file

The `FileIndex` object is used to keep the values of some of the GRIB keys into memory. The keys to be kept are defined with the `index_keys` keyword argument (by default, `GRIBDatasets.ALL_KEYS`).
It is also possible to filter on specific values for the keys with the `filter_by_values` keyword argument. This can significantly improve the performance for reading the file:

```@example fileindex
using GRIBDatasets
using BenchmarkTools

dir_tests = abspath(joinpath(dirname(pathof(GRIBDatasets)), "..", "test"))
grib_path = abspath(joinpath(dir_tests, "sample-data", "era5-levels-members.grib"))
nothing #hide
```

```@repl fileindex
only_geopotential_on_500_hPa  = Dict(
    "cfVarName" => "z",
    "level" => 500,
)
@btime filtered_index = FileIndex(grib_path; filter_by_values = only_geopotential_on_500_hPa);

@btime index = FileIndex(grib_path);
```