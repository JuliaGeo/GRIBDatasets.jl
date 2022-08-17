# GRIBDatasets

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://tcarion.github.io/GRIBDatasets.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://tcarion.github.io/GRIBDatasets.jl/dev/)
[![Build Status](https://github.com/tcarion/GRIBDatasets.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/tcarion/GRIBDatasets.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/tcarion/GRIBDatasets.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/tcarion/GRIBDatasets.jl)

## Description

GRIBDatasets.jl uses [GRIB.jl](https://weech.github.io/GRIB.jl) to provide a higher level interface for reading GRIB file. It tries to follow the same approach as [NCDatasets.jl](https://github.com/JuliaGeo/NetCDF.jl).

To read a GRIB file, just type:

```julia
using GRIBDatasets

ds = GRIBDataset("example.grib")
Dataset from file: example.grib
Dimensions:
         longitude = 120
         latitude = 61
         number = 10
         valid_time = 4
         level = 2
Layers:
z, t
with attributes:
Dict{String, Any} with 5 entries:
  "edition"           => "1"
  "centreDescription" => "European Centre for Medium-Range Weather Forecasts"
  "centre"            => "ecmf"
  "subCentre"         => "0"
  "Conventions"       => "CF-1.7"
```

Then you can access a variable with `z = ds["z"]`, and slice according to the variable dimensions:

```julia
z[:,:, 2, 1:2, 1]
```

This package is similar to [CfGRIB.jl](https://github.com/ecmwf/cfgrib.jl), but some part of the code has been rewritten so it can be easily integrated to [Rasters.jl](https://github.com/rafaqz/Rasters.jl). It is recommended to use directly Rasters.jl, so the user can benefit from its nice features.