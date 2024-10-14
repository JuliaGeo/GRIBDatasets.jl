using GRIBDatasets
using GRIBDatasets: _alldims, _horizontal_gridtype, _horizdims, _dim_values, _size_dims, _otherdims, _verticaldims
using GRIBDatasets: _separate_distinct_levels, _get_dim
using GRIBDatasets: Horizontal, Vertical, Other, NonHorizontal
using GRIBDatasets: RegularGrid, NonRegularGrid, OtherGrid
using GRIBDatasets: MessageDimension, IndexedDimension, ArtificialDimension, Dimensions, AbstractDim
using GRIBDatasets: dimlength, dimname
using GRIBDatasets: filter_messages, message_indices, message_indice, messages_indices
using GRIBDatasets: _get_verticaldims, _get_horizontaldims, _get_otherdims, additional_coordinates_varnames
using GRIBDatasets: _is_in_artificial, _replace_with_artificial, _is_length_consistent
using Test

@testset "dimension from index" begin
    era5_path = joinpath(dir_testfiles, "era5-levels-members.grib")
    era5 = FileIndex(era5_path)

    regular_gg_path = joinpath(dir_testfiles, "regular_gg_pl.grib")
    regular_gg = FileIndex(regular_gg_path)

    lambert_path = joinpath(dir_testfiles, "lambert_grid.grib")
    lambert = FileIndex(lambert_path)

    reduced_gg_path = joinpath(dir_testfiles, "reduced_gg.grib")
    reduced_gg = FileIndex(reduced_gg_path)

    @test _horizontal_gridtype(era5) == RegularGrid
    @test _horizontal_gridtype(regular_gg) == RegularGrid
    @test _horizontal_gridtype(lambert) == NonRegularGrid
    @test _horizontal_gridtype(reduced_gg) == OtherGrid

    erahoriz = _horizdims(era5, _horizontal_gridtype(era5))
    @test erahoriz[1] isa MessageDimension{<:Horizontal}
    @test dimname(erahoriz[1]) == "lon"

    eraother = _otherdims(era5)
    @test eraother[1] isa IndexedDimension
    
    eravertical = _verticaldims(era5)
    @test eravertical[1].name == "isobaricInhPa"

    era_alldims = _alldims(era5)
    @test era_alldims isa Dimensions

    @test dimname.(_get_verticaldims(era_alldims)) == dimname.(eravertical)

    # for lonlat grid, x dim must be one dimensional
    @test _dim_values(era5, era_alldims[1]) isa Vector
    lam_alldims = _alldims(lambert)
    # for lambert grid, x dim must be 2D
    @test isnothing(_dim_values(lambert, lam_alldims[1]))
    
    @test isnothing(_dim_values(reduced_gg, _alldims(reduced_gg)[1]))

    @test additional_coordinates_varnames(lam_alldims) == ["longitude", "latitude"]
    @test additional_coordinates_varnames(era_alldims) == []

    # first dimensions must be the horizontal ones
    @test keys(era_alldims)[1:2] == ["lon", "lat"]

    @test _size_dims(era_alldims) == (120, 61, 2, 10, 4)

    @testset "message indices" begin
        dim = era_alldims[1]
        mind = era5.messages[1]
        vertdim = _get_verticaldims(era_alldims)[1]
        @test message_indices(era5, mind, era_alldims) == [1, 1, 1]

        indices = messages_indices(era5, era_alldims)
        length(unique([e[2] for e in indices])) == 10
    end

    @testset "redundant vertical dims" begin
        index = FileIndex(joinpath(dir_testfiles, "ENH18080914"))
        filtered_index = filter_messages(index, typeOfLevel = "heightAboveGround")
        distinct = _separate_distinct_levels(filtered_index; tocheck = "level")
        @test length(distinct) == 2

        vertdims = _verticaldims(index)

        @test keys(vertdims) == ["hybrid", "heightAboveGround", "heightAboveGround_2"]

        u10 = filter_messages(index, cfVarName = "avg_10u")
        indices = messages_indices(u10, _alldims(u10))

        @test indices[1] == [1, 1]
    end
end
