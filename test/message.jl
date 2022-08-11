using GRIBDatasets
using GRIBDatasets: read_message, ALL_KEYS, MessageIndex
using GRIB

const dir_tests = abspath(joinpath(dirname(pathof(GRIBDatasets)), "..", "test"))
const dir_testfiles = abspath(joinpath(dir_tests, "sample-data"))

grib_path = readdir(dir_testfiles, join=true)[2]

f = GribFile(grib_path)
message = first(f)
index_keys = ALL_KEYS
values = read_message.(Ref(message), ALL_KEYS)
offset = message["offset"]

mindex = MessageIndex(message)

mindex["stepType"]