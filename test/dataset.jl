using GRIBDatasets
using GRIBDatasets: FileIndex, _geography, Variable, NonHorizontal, Dimension, Geography, Dimensions
using GRIBDatasets: _geodims, _otherdims, OtherDim, _alldims, getone
using GRIBDatasets: DATA_ATTRIBUTES_KEYS, GRID_TYPE_MAP
using Pkg
Pkg.activate("test")
using BenchmarkTools
Pkg.activate(".")

G = GRIBDatasets

const dir_tests = abspath(joinpath(dirname(pathof(GRIBDatasets)), "..", "test"))
const dir_testfiles = abspath(joinpath(dir_tests, "sample-data"))

grib_path = readdir(dir_testfiles, join=true)[2]

index = FileIndex(grib_path)

ds = GRIBDataset(index)

dimvar = Variable(ds, ds.dims[4])

layer_index = G.filter_messages(index, paramId = 129)
ldims = G._alldims(layer_index)

all_indices = G.messages_indices(layer_index, ldims)

layer_var = Variable(ds, "t")

layer_var[:,:,3,1,1,1,2]

for test_file in readdir(dir_testfiles, join=true)[2:end]
    println("Testing $test_file")
    ds = GRIBDataset(test_file)
    firstlayer = G.getlayersname(ds) |> first
    var = ds[firstlayer]
    I = first(CartesianIndices(var))
    var[I]
end