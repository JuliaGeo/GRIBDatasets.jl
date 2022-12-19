using GRIBDatasets
using GRIBDatasets: _alldims, _horizontaltype, _horizdim, _dim_values, _size_dims
using GRIBDatasets: Horizontal, Vertical, Other, NonHorizontal
using GRIBDatasets: Lonlat, NonDimensionCoords, NoCoords
using GRIBDatasets: Dimension, Dimensions
using GRIBDatasets: TupleDims
using GRIBDatasets: from_message, from_index, getdims

@testset "dimension from index" begin
    era5_path = joinpath(dir_testfiles, "era5-levels-members.grib")
    era5 = FileIndex(era5_path)

    gaussian_path = joinpath(dir_testfiles, "regular_gg_pl.grib")
    gaussian = FileIndex(gaussian_path)

    lambert_path = joinpath(dir_testfiles, "lambert_grid.grib")
    lambert = FileIndex(lambert_path)

    @test _horizontaltype(era5) == Lonlat
    @test _horizontaltype(gaussian) == Lonlat
    @test _horizontaltype(lambert) == NonDimensionCoords

    erahoriz = _horizdim(era5, _horizontaltype(era5))
    @test erahoriz[1] isa Dimension{Horizontal}
    @test erahoriz[1].name == "longitude"


    
    era_alldims = _alldims(era5)
    @test era_alldims isa TupleDims
    # for lonlat grid, x dim must be one dimensional
    @test _dim_values(era5, era_alldims[1]) isa Vector
    lam_alldims = _alldims(lambert)
    # for lambert grid, x dim must be 2D
    @test _dim_values(lambert, lam_alldims[1]) isa Matrix

    @testset "Dimensions" begin
        dims = Dimensions(era5)
        @test keys(dims)[1:2] == ["longitude", "latitude"]
        @test getdims(dims) isa TupleDims
        @test "number" in dims
        @test dims["number"] == era_alldims[3]
        @test from_message(dims) == era_alldims[1:2]
        @test from_index(dims) == era_alldims[3:end]
    end

    # vertdim = era_alldims["level"]
    # @test length(_dim_values(era5, vertdim)) == vertdim.length

    @test _size_dims(era_alldims) == (120, 61, 10, 4, 2)
end