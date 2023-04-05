using GRIBDatasets
using Dates
using Test
using GRIBDatasets: getone
using GRIBDatasets: Variable
using GRIBDatasets: DATA_ATTRIBUTES_KEYS, GRID_TYPE_MAP
using GRIBDatasets: _to_datetime
using GRIBDatasets: DiskValues, Variable


@testset "dataset and variables" begin
    grib_path = joinpath(dir_testfiles, "era5-levels-members.grib")
    ds = GRIBDataset(grib_path)
    index = ds.index

    varstring = "z"
    @testset "dataset indexing" begin
        vars = keys(ds)
        @test vars[1] == "lon"
    
        @test GDS.getlayersname(ds)[1] == "z"
    
        @test length(ds.dim) == 5
    
        @test ds.attrib["centre"] == getone(index, "centre")
    end

    @testset "dim as variable" begin
        dimvar = ds["longitude"]
        @test dimvar isa Variable
        @test collect(dimvar) isa AbstractArray
        @test dimvar[1:2] == [0., 3.]
    end

    @testset "variable indexing" begin
        layer = ds[varstring]
        @test layer isa AbstractArray
        @test layer[:,:,1,1,1] isa AbstractMatrix
        lsize = size(layer)
        @test layer[lsize...] isa Number

        #indexing on the message dimensions
        @test layer[1:10, 2:4, 1, 1, 1] isa AbstractArray{<:Any, 2}

        #indexing on the other dimensions
        @test layer[1, 1, 1:2, 1:3, 1:2] isa AbstractArray{<:Any, 3}

        #indexing on the all dimensions
        @test layer[5:10, 2:4, 1:2, 1:3, 1:2] isa AbstractArray{<:Any, 5}
    end

    @testset "variable indexing with redundant level" begin
        ds2 = GRIBDataset(joinpath(dir_testfiles, "ENH18080914"))

        u = ds2["u"]
        @test u[:,:, 1, 1] isa AbstractArray{<:Any, 2}

        @test_throws BoundsError u[:,:,1,2]

        u10 = ds2["u10"]

        t2 = ds2["t2m"]
    end

    @testset "upfront filtering" begin
        only_first_member = Dict("number" => 1)

        ds = GRIBDataset(grib_path; filter_by_values = only_first_member)
        length(ds["number"]) == 1
    end

    @testset "variable attributes" begin
        layer = ds[varstring]

        @test layer.attrib["cfName"] == GDS.getone(GDS.filter_messages(index; shortName=varstring), "cfName")
    end

    @testset "utils" begin
        todt = _to_datetime.(ds["valid_time"])
        @test todt[1] == DateTime("2017-01-01T00:00:00")
        @test length(todt) == 4
    end
end

@testset "test all files" begin
    for testfile in test_files
        println("Testing: ", testfile)
        index = FileIndex(testfile)
        println("grid type: ", first(index["gridType"]))

        @time ds = GRIBDataset(testfile)

    end

end