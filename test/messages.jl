using GRIBDatasets
using GRIBDatasets: read_message, ALL_KEYS, MessageIndex
using GRIB



@testset "message index" begin
    grib_path = joinpath(dir_testfiles, "era5-levels-members.grib")
    f = GribFile(grib_path)
    message = first(f)
    valid = read_message(message, "valid_time")
    time = read_message(message, "time")

    @test valid == time

    mindex = MessageIndex(message)

    @test mindex["dataType"] == "an"
    @test length(mindex) == 14752
    @test GDS.getoffset(mindex) == message["offset"]

    # Filter the keys to be read
    mindex2 = MessageIndex(message; index_keys = ["shortName"])
    @test length(GDS.getheaders(mindex2)) == 1

    destroy(f)
end