# GRIBDatasets

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliageo.org/GRIBDatasets.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliageo.org/GRIBDatasets.jl/dev/)
[![Build Status](https://github.com/JuliaGeo/GRIBDatasets.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaGeo/GRIBDatasets.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaGeo/GRIBDatasets.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaGeo/GRIBDatasets.jl)

## Description

GRIBDatasets.jl uses [GRIB.jl](https://weech.github.io/GRIB.jl) to provide a higher level interface for reading GRIB files. This package implements the [CommonDataModel.jl](https://github.com/JuliaGeo/CommonDataModel.jl) interface, which mean that the datasets can be accessed in the same way as netCDF files opened with [NCDatasets.jl](https://github.com/Alexander-Barth/NCDatasets.jl).

To read a GRIB file, just type:

```julia
julia> using GRIBDatasets

julia> ds = GRIBDataset("example.grib")
Dataset: example.grib
Group: /

Dimensions
   lon = 120
   lat = 61
   valid_time = 4

Variables
  lon   (120)
    Datatype:    Float64 (Float64)
    Dimensions:  lon
    Attributes:
     units                = degrees_east
     long_name            = longitude
     standard_name        = longitude

  lat   (61)
    Datatype:    Float64 (Float64)
    Dimensions:  lat
    Attributes:
     units                = degrees_north
     long_name            = latitude
     standard_name        = latitude

  valid_time   (4)
    Datatype:    Dates.DateTime (Int64)
    Dimensions:  valid_time
    Attributes:
     units                = seconds since 1970-01-01T00:00:00
     calendar             = proleptic_gregorian
     long_name            = time
     standard_name        = time

  z   (120 × 61 × 4)
    Datatype:    Union{Missing, Float64} (Float64)
    Dimensions:  lon × lat × valid_time
    Attributes:
     units                = m**2 s**-2
     long_name            = Geopotential
     standard_name        = geopotential

  t   (120 × 61 × 4)
    Datatype:    Union{Missing, Float64} (Float64)
    Dimensions:  lon × lat × valid_time
    Attributes:
     units                = K
     long_name            = Temperature
     standard_name        = air_temperature

Global attributes
  edition              = 1
  source               = /home/tcarion/.julia/dev/GRIBDatasets/test/sample-data/era5-levels-members.grib
  centreDescription    = European Centre for Medium-Range Weather Forecasts
  centre               = ecmf
  subCentre            = 0
  Conventions          = CF-1.7
```

Indexing on the `GRIBDataset` object gives you the variable, which is an `AbstractArray` that can be sliced according to the required dimensions:

```julia
julia> t = ds["t"];
julia> t[1:3,1:5,1]
3×5 Matrix{Union{Missing, Float64}}:
 233.31  231.276  230.121  229.144  229.072
 233.31  231.229  230.053  229.212  228.893
 233.31  231.174  229.942  229.064  228.84

julia> ds["valid_time"][:]
4-element Vector{Dates.DateTime}:
 2017-01-01T00:00:00
 2017-01-01T12:00:00
 2017-01-02T00:00:00
 2017-01-02T12:00:00
```

The attributes of any variable can be accessed this way:
```julia
julia> ds["z"].attrib
Dict{String, Any} with 3 entries:
  "units"         => "m**2 s**-2"
  "long_name"     => "Geopotential"
  "standard_name" => "geopotential"
```

This package is similar to [CfGRIB.jl](https://github.com/ecmwf/cfgrib.jl), but the code has been adapted to be more Julian and to follow the `CommonDataModel` interface.

## Writing
It's currently not possible to write the datasets to the GRIB format. If you want to modify the dataset, you need to convert it first to NetCDF and use NCDatasets. Converting a GRIB file to NetCDF is straightforward:

```julia
using NCDatasets
using GRIBDatasets
using Downloads: download

grib_file = download("https://github.com/JuliaGeo/GRIBDatasets.jl/raw/98356af026ea39a5ec0b5e64e4289105492321f8/test/sample-data/era5-levels-members.grib")
netcdf_file = "test.nc"
NCDataset(netcdf_file,"c") do ds
    write(ds,GRIBDataset(grib_file))
end
```
## Opening issues:
GRIB format files may have a (very) large amount of different shapes. `GRIBDatasets` might not work for your specific edge case. If this happens, please open an issue, if possible providing the file triggering the bug.

## Windows support is experimental
The windows support is still under development. Most test cases works on windows but a few still fail. See issue GRIB.jl for more information https://github.com/weech/GRIB.jl/issues/14