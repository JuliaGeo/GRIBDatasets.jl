using GRIBDatasets
using GRIBDatasets: FileIndex, _geography, Variable
using Pkg
Pkg.activate("test")
using BenchmarkTools
Pkg.activate(".")

G = GRIBDatasets

const dir_tests = abspath(joinpath(dirname(pathof(GRIBDatasets)), "..", "test"))
const dir_testfiles = abspath(joinpath(dir_tests, "sample-data"))

grib_path = readdir(dir_testfiles, join=true)[1]

index = FileIndex(grib_path)

ds = GRIBDataset(index)

var = Variable(ds, ds.dims[4])

layer_index = G.filter_messages(index, paramId = 129)
ldims = G._alldims(layer_index)

G.get_offsets.(Ref(layer_index), "number", [0, 2])