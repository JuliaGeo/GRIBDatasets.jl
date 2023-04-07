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

# gi = Index(joinpath(dir_testfiles, "ENH18080914"), "cfVarName")
# select!(gi, "cfVarName", "sdor")
# msdor = first(gi)
# msdor["validityDate"], msdor["validityTime"]
# mind = MessageIndex(msdor)

# gi2 = Index(joinpath(dir_testfiles, "ENH18080914"), "cfVarName")
# select!(gi2, "cfVarName", "u")
# mu = first(gi2)
# mu["validityDate"], mu["validityTime"]

# mindu = MessageIndex(mu)


# function to_dict(m::Message)
#     ks = string.(keys(m))
#     Dict(k => m[k] for k in ks)
# end

# f = GribFile(grib_path)

# wanted = collect(Iterators.filter(grib) do msg
#     msg["typeOfLevel"] == "hybrid"
# end)