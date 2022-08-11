module GRIBDatasets

using GRIB
using DataStructures
using DiskArrays

const DA = DiskArrays
# Write your package code here.

include("constants.jl")
include("utils.jl")
include("cfmessage.jl")
include("index.jl")
include("dimensions.jl")
include("dataset.jl")
include("variables.jl")

export GRIBDataset

end
