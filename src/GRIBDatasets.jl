module GRIBDatasets

using Dates
using GRIB
using DataStructures
using DiskArrays

const DA = DiskArrays

const DEFAULT_EPOCH = DateTime(1970, 1, 1, 0, 0)

include("constants.jl")
include("utils.jl")
include("messages.jl")
include("index.jl")
include("dimensions.jl")
include("dataset.jl")
include("variables.jl")

export GRIBDataset

end
