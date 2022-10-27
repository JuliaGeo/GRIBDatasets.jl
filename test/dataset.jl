using GRIBDatasets
using Test
using GRIBDatasets: getone
using GRIBDatasets: DATA_ATTRIBUTES_KEYS, GRID_TYPE_MAP


@testset "dataset and variables" begin
    grib_path = joinpath(dir_testfiles, "era5-levels-members.grib")
    ds = GRIBDataset(grib_path)
    index = ds.index

    varstring = "z"
    @testset "dataset indexing" begin
        vars = keys(ds)
        @test vars[1] == "longitude"
    
        @test GDS.getlayersname(ds)[1] == "z"
    
        @test length(ds.dims) == 5
    
        @test ds.attrib["centre"] == getone(index, "centre")
    end

    @testset "variable indexing" begin
        layer = ds[varstring]
        @test layer isa AbstractArray
        @test layer[:,:,1,1,1] isa AbstractMatrix
        lsize = size(layer)
        @test layer[lsize...] isa Number

        #indexing on the message dimensions
        @test layer[1:10, 2:4, 1, 1, 1] isa AbstractArray{<:Any, 2}

        #indexing on the other dimensions
        @test layer[1, 1, 1:3, 1:2, 1:2] isa AbstractArray{<:Any, 3}

        #indexing on the all dimensions
        @test layer[5:10, 2:4, 1:3, 1:2, 1:2] isa AbstractArray{<:Any, 5}
    end

    @testset "variable attributes" begin
        layer = ds[varstring]

        @test layer.attrib["cfName"] == GDS.getone(GDS.filter_messages(index; shortName=varstring), "cfName")
    end
end

@testset "test all files" begin
    for testfile in test_files
        println("Testing: ", testfile)
        index = FileIndex(testfile)
        println("grid type: ", first(index["gridType"]))

        ds = GRIBDataset(testfile)

    end

end

# grib_path = readdir(dir_testfiles, join=true)[2]

# index = FileIndex(grib_path)

# ds = GRIBDataset(index)
# ds = GRIBDataset(grib_path)

# dimvar = Variable(ds, ds.dims[4])

# ldims = GDS._alldims(layer_index)

# all_indices = GDS.messages_indices(layer_index, ldims)

# layer_var = Variable(ds, "t")

# layer_var[:,:,3,1,1,1,2]

# for test_file in readdir(dir_testfiles, join=true)[2:end]
#     println("Testing $test_file")
#     ds = GRIBDataset(test_file)
#     firstlayer = GDS.getlayersname(ds) |> first
#     var = ds[firstlayer]
#     I = first(CartesianIndices(var))
#     var[I]
# end