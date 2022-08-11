using GRIBDatasets
using GRIB
using GRIBDatasets: FileIndex, filter_messages, with_messages, enforce_unique_attributes

const dir_tests = abspath(joinpath(dirname(pathof(GRIBDatasets)), "..", "test"))
const dir_testfiles = abspath(joinpath(dir_tests, "sample-data"))

grib_path = readdir(dir_testfiles, join=true)[2]

index = FileIndex(grib_path)

filter_messages(index, "paramId", 129)
filter_messages(index, paramId = 129, level = 500)
with_messages(index; paramId = 129, level = 500) do m
    println(m["level"])
end

enforce_unique_attributes(index, ["edition"])
# @benchmark FileIndex(grib_path)
# @benchmark GribFile(grib_path) do f
#     for m in f
#         string.(keys(m))
#     end
# end

d = DefaultDict{AbstractString, Vector{Any}}(() -> Vector{Any}())
for (k, v) in messages[1].headers
    if v ∉ d[k]
        push!(d[k], v)
    end
end