using GRIBDatasets
using Dates
using Test
using GRIBDatasets: getone
using GRIBDatasets: Variable
using GRIBDatasets: DATA_ATTRIBUTES_KEYS, GRID_TYPE_MAP
using GRIBDatasets: _to_datetime
using GRIBDatasets: DiskValues, Variable, CFVariable, cfvariable
using GRIBDatasets: CDM
using DiskArrays

grib_path = joinpath(dir_testfiles, "era5-levels-members.grib")
varstring = "z"

@testset "dataset and variables" begin
    ds = GRIBDataset(grib_path)
    dsmis = GRIBDataset(joinpath(dir_testfiles, "fields_with_missing_values.grib"))
    dsNaN = GRIBDataset(joinpath(dir_testfiles, "fields_with_missing_values.grib"),maskingvalue = NaN)
    index = ds.index

    @testset "CommonDataModel implementation" begin
        @test CDM.dim(ds, "number") == 10
        @test length(CDM.dimnames(ds)) == 5
        @test CDM.dims(ds) isa AbstractDict
        @test CDM.dims(ds)["number"] == 10

        var = ds["z"]
        @test length(CDM.dimnames(var)) == 5

        @test CDM.dataset(var) == ds

        @test CDM.name(ds[:t]) == CDM.name(ds["t"])
    end

    @testset "dataset indexing" begin
        vars = keys(ds)
        @test vars[1] == "lon"
        @test GDS.getlayersname(ds)[1] == "z"
        @test length(ds.dims) == 5
        @test ds.attrib["centre"] == getone(index, "centre")
    end

    @testset "dim as variable" begin
        @testset "message dim" begin
            dimvar =  Variable(ds, "lon")
            @test dimvar isa Variable
            @test collect(dimvar) isa AbstractArray
            @test dimvar[1:2] == [0., 3.]
        end

        @testset "indexed dim" begin
            dimvar = Variable(ds, "number")
            @test dimvar isa Variable
            @test collect(dimvar) isa AbstractArray
            @test dimvar[1:2] == [0, 1]
        end

        @testset "vertical dim" begin
            dimvar = Variable(ds, "isobaricInhPa")
            @test dimvar isa Variable
            @test collect(dimvar) isa AbstractArray
            @test dimvar[1:2] == [500, 850]
        end
    end

    @testset "variable indexing" begin
        @test ds[varstring] isa CFVariable

        layer = Variable(ds, varstring)
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

        @testset "with missing values" begin
            t2m = Variable(dsmis, "t2m")
            misval = GDS.missing_value(t2m)
            ht2m = t2m[:,:,1,1]
            @test ht2m isa Matrix{Float64}
            @test any(ht2m .== misval)
        end

        @testset "cfvariable and missing" begin
            cfvar = cfvariable(ds, varstring)
            cfvarmis = cfvariable(dsmis, "t2m")
            cfvarNaN = cfvariable(dsNaN, "t2m")
            A = cfvar[:,:,1,1,1]
            Amis = cfvarmis[:,:,1,1]
            ANaN = cfvarNaN[:,:,1,1]

            # With CommonDataModel, we necessarily get a Union{Missing, Float64}, even if there's no missing.
            @test_broken eltype(A) == Float64
            @test eltype(Amis) == Union{Missing, Float64}
            @test eltype(ANaN) == Float64

            # test the use of a different maskingvalue per dataset
            @test eltype(dsmis["t2m"]) == Union{Missing,Float64}
            @test eltype(dsNaN["t2m"]) == Float64
            @test ismissing(Amis[1,1,1])
            @test isnan(ANaN[1,1,1])

            # test the use of a different maskingvalue per variable
            A2NaN = cfvariable(dsmis,"t2m", maskingvalue = NaN)
            @test isnan(A2NaN[1,1,1])
        end

        @testset "cfvariable coordinate" begin
            cflon = cfvariable(ds, "lon")
            length(cflon[:]) == 120
            cfnum = cfvariable(ds, "number")
            length(cfnum[:]) == 10
        end
    end

    @testset "variable indexing with redundant level" begin
        ds2 = GRIBDataset(joinpath(dir_testfiles, "ENH18080914"))
        u = ds2["u"]
        @test u[:,:, 1, 1] isa AbstractArray{<:Any, 2}
        @test_throws BoundsError u[:,:,1,2]
        u10 = ds2["avg_10u"]
        @test GDS._dim_values(GDS._get_dim(u10, "heightAboveGround_2")) == [10]
        t2m = ds2["mean2t"]
        @test GDS._dim_values(GDS._get_dim(t2m, "heightAboveGround")) == [2]
    end

    @testset "upfront filtering" begin
        only_one_level = Dict("level" => 500)
        dsf = GRIBDataset(grib_path; filter_by_values = only_one_level)
        @test length(dsf["isobaricInhPa"]) == 1
    end

    @testset "variable attributes" begin
        layer = Variable(ds, varstring)
        @test layer.attrib["cfName"] == GDS.getone(GDS.filter_messages(index; shortName=varstring), "cfName")
    end

    @testset "cfvariable attributes" begin
        cflayer = ds[varstring]
        @test cflayer.attrib["standard_name"] == GDS.getone(GDS.filter_messages(index; shortName=varstring), "cfName")
        @test ds["lon"].attrib["standard_name"] == "longitude"
    end

    @testset "time dimension" begin
        @test ds["valid_time"][1] isa DateTime
    end

    @testset "reduced gaussian grid" begin
        reduced_gg_path = joinpath(dir_testfiles, "reduced_gg.grib")

        dsrgg = GRIBDataset(reduced_gg_path)

        @test haskey(dsrgg, "longitude")
        @test haskey(dsrgg, "latitude")

        @test dsrgg["latitude"] isa AbstractVector
        @test size(dsrgg["longitude"]) == (GDS.dimlength(dsrgg.dims[1]), )
        @test dsrgg["longitude"][1:3] == [0.,18.,36.]
        @test dsrgg["latitude"][:] == dsrgg.index._first_data[2][:]
    end

    @testset "lamber grid" begin
        lambert_path = joinpath(dir_testfiles, "lambert_grid.grib")
        lambert = GRIBDataset(lambert_path)

        @test haskey(lambert, "longitude")
        @test haskey(lambert, "latitude")

        @test lambert["latitude"] isa AbstractMatrix
        @test lambert["longitude"] isa AbstractMatrix

        @test lambert["latitude"][:] == lambert.index._first_data[2][:]
    end

    @testset "filter dataset by values" begin
        fds = GRIBDataset(grib_path; filter_by_values = Dict("cfVarName" => "t"))

        @test !haskey(fds, "z")

        @test all(fds["t"].var.values.offsets .== ds["t"].var.values.offsets)
        @test all(ds["t"][:,:,2, 3, 2] .== fds["t"][:,:,2, 3, 2])
        @test all(ds["t"][:,:,2, 3:4, 2] .== fds["t"][:,:,2, 3:4, 2])
    end
end

@testset "open all files" begin
    for testfile in test_files
        println("Testing: ", testfile)
        index = FileIndex(testfile)
        println("grid type: ", first(index["gridType"]))
        @time ds = GRIBDataset(testfile)
    end

end

@testset "tests on specific grib files" begin
    # issue 41
    withsteps = GRIBDataset(joinpath(dir_testfiles, "regular_ll_msl_with_steps.grib"))
    @test size(withsteps["valid_time"]) == (length(withsteps["time"]), length(withsteps["step"]))
    @test size(withsteps["msl"][:,:,:,:]) == (3,3,62,4)
end

@testset "diskarrays" begin
    # No scalar indexing allowed
    DiskArrays.allowscalar(false)
    ds = GRIBDataset(grib_path)
    # CFVariable is not a disk array, so will be super slow here.
    # But the underlying variable is
    var = ds[varstring].var
    @test DiskArrays.isdisk(var)
    # Currently just one huge chunk
    @test length(DiskArrays.eachchunk(var)) == 1
    # Broadcasts are lazy
    B = var .* 10
    @test B isa DiskArrays.BroadcastDiskArray
    @test B[1:50, 1:50, 1, 1, 1] isa Matrix
    # Reduction is chunked
    @test sum(var) * 10 == sum(B) 
end