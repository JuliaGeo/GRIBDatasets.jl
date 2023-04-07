using GRIBDatasets
using GRIB
using GRIBDatasets: FileIndex, filter_messages, with_messages
using GRIBDatasets: get_values_from_filtered
using GRIBDatasets: build_valid_time, _to_datetime

@testset "index creation" begin
    grib_path = joinpath(dir_testfiles, "era5-levels-members.grib")
    index = FileIndex(grib_path)

    @test index["edition"] == [1]
    @test GDS.getone(index, "Nx") == 120
    # More than 1 variable in this dataset, should error
    @test_throws ErrorException GDS.getone(index, "shortName")

    @test length(index) == 160
end

@testset "filtering upfront" begin
    grib_path = joinpath(dir_testfiles, "era5-levels-members.grib")
    filter_by_values = Dict(
        "cfVarName" => "z",
        "level" => 500,
    )

    index = FileIndex(grib_path; filter_by_values)

    @test GDS.getone(index, "shortName") == "z"

    @test length(index) == 40
end

@testset "filtering index" begin
    grib_path = joinpath(dir_testfiles, "era5-levels-members.grib")
    index = FileIndex(grib_path)

    mindexs = GDS.getmessages(index)
    @test mindexs isa Vector{MessageIndex}

    @test length(filter_messages(mindexs, "shortName", "z")) == 80
    @test length(filter_messages(mindexs, shortName = "z", number = 1)) == 8
end

@testset "utils" begin
    grib_path = joinpath(dir_testfiles, "era5-levels-members.grib")
    index = FileIndex(grib_path)
    vals = get_values_from_filtered(index, "cfVarName", "level")
    @test length(vals) == 2
end

@testset "ENH18080914" begin
    index = FileIndex(joinpath(dir_testfiles, "ENH18080914"))
    in1 = filter_messages(index; valid_time = 1533823200)
    in2 = filter_messages(index; valid_time = 1533772800)

    dt1 = _to_datetime.(in1["valid_time"])
    dt2 = _to_datetime.(in2["valid_time"])
end
# with_messages(index; paramId = 129, level = 500) do m
#     println(m["level"])
# end