using GRIBDatasets
using Test

GDS = GRIBDatasets

const dir_tests = abspath(joinpath(dirname(pathof(GRIBDatasets)), "..", "test"))
const dir_testfiles = abspath(joinpath(dir_tests, "sample-data"))

test_files = joinpath.(dir_testfiles, [
    "era5-levels-members.grib", # OK
    "fields_with_missing_values.grib", # OK
    "forecast_monthly_ukmo.grib", # Failing because because there are multiple steps
    "lambert_grid.grib", # longitude and latitude are 2D variables. Don't know what to do in this case
    "multi_param_on_multi_dims.grib", # Passing, but we loose the information on number and time. Should be fixed
    "regular_gg_ml.grib", # OK
    "regular_gg_ml_g2.grib", # OK
    "regular_gg_pl.grib", # OK
    "regular_gg_sfc.grib", # OK
    "regular_ll_msl.grib", # OK
    "regular_ll_sfc.grib", # OK
    "regular_ll_wrong_increment.grib", # OK
    "scanning_mode_64.grib", # OK
    "t_analysis_and_fc_0.grib", # OK
])

@testset "GRIBDatasets.jl" begin
    @testset "messages" begin include("messages.jl") end
    @testset "message index" begin include("index.jl") end
    @testset "dimensions" begin include("dimensions.jl") end
    @testset "dataset" begin include("dataset.jl") end
end
