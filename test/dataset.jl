using GRIBDatasets
using GRIBDatasets: FileIndex, _geography, Variable

G = GRIBDatasets

const dir_tests = abspath(joinpath(dirname(pathof(GRIBDatasets)), "..", "test"))
const dir_testfiles = abspath(joinpath(dir_tests, "sample-data"))

grib_path = readdir(dir_testfiles, join=true)[2]

index = FileIndex(grib_path)

ds = GRIBDataset(index)

var = Variable(ds, ds.dims[4])

layer_messages = G.filter_messages(index, paramId = 129)