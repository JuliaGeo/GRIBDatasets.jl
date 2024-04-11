module GRIBDatasets

using Dates
using GRIB
using DataStructures
import DiskArrays as DA
using CommonDataModel: AbstractDataset, AbstractVariable, show_dim, CFVariable
import CommonDataModel: path, name, dimnames, isopen, attribnames, attrib,
    dataset, maskingvalue
import CommonDataModel as CDM

const DEFAULT_EPOCH = DateTime(1970, 1, 1, 0, 0)

include("constants.jl")
include("utils.jl")
include("messages.jl")
include("index.jl")
include("dimensions.jl")
include("dataset.jl")
include("variables.jl")
include("cfvariables.jl")

export GRIBDataset, FileIndex, dimnames

end
