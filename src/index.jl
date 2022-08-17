using DataStructures


export FileIndex

"""
Store for the messages of a GRIB file. Keeps track of the offset of the GRIB messages so they
can be easily `seeked`. The `unique_headers` property gives all the different values for the keys
in the GRIB file. 
"""
struct FileIndex{T}
    "Path to the file the index belongs to"
    grib_path::String
    messages::Vector{<:MessageIndex}
    unique_headers::Dict{AbstractString, Vector{Any}}
    "We keep the data of the first message to avoid re-reading for getting x-y coordinates"
    _first_data
end
getheaders(index::FileIndex) = index.unique_headers

"""
    FileIndex(grib_path::String; index_keys = ALL_KEYS)

Construct a [`FileIndex`](@ref) for the file `grib_path`, storing only the keys in `index_keys`.
The values of the headers can be accessed with `getindex`

# Example

```jldoctest
index = FileIndex(example_file)

# output
FileIndex{Float64} with 160 messages
Headers summary:
Dict{AbstractString, Vector{Any}} with 39 entries:
  "edition"                          => [1]
  "jDirectionIncrementInDegrees"     => [3.0]
  "number"                           => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  "time"                             => [1483228800, 1483272000, 1483315200, 14…
  "dataType"                         => ["an"]
  "stepUnits"                        => [1]
  "subCentre"                        => [0]
  "jPointsAreConsecutive"            => [0]
  "level"                            => [500, 850]
  "name"                             => ["Geopotential", "Temperature"]
  "step"                             => [0]
  "jScansPositively"                 => [0]
  "latitudeOfLastGridPointInDegrees" => [-90.0]
  "valid_time"                       => [1483228800, 1483272000, 1483315200, 14…
  "dataDate"                         => [20170101, 20170102]
  "iScansNegatively"                 => [0]
  "numberOfPoints"                   => [7320]
  "missingValue"                     => [9999]
  "gridType"                         => ["regular_ll"]
  ⋮                                  => ⋮
```
"""
function FileIndex(grib_path::String; index_keys = ALL_KEYS)
    messages = MessageIndex[]
    datatype = nothing
    fdata = []
    unique_headers = DefaultDict{AbstractString, Vector{Any}}(() -> Vector{Any}())

    # f = GribFile(grib_path)
    GribFile(grib_path) do f
        for (i, m) in enumerate(f)
            # Infer the data type from the values of the first message
            if i==1
                fdata = data(m)
                datatype = eltype(fdata[3])
            end
            mindex = MessageIndex(m, index_keys = index_keys)
            _add_headers!(unique_headers, mindex)
            push!(messages, mindex)
        end
    end
    # destroy(f)
    # _filter_missing!(unique_headers)
    FileIndex{datatype}(grib_path, messages, unique_headers, fdata)
end

function Base.show(io::IO, mime::MIME"text/plain", index::FileIndex) 
    println(io, "$(typeof(index)) with $(length(index)) messages")
    println(io, "Headers summary:")
    show(io, mime, getheaders(index))
end

getmessages(index::FileIndex) = index.messages
Base.getindex(index::FileIndex, key::String) = getheaders(index)[key]
Base.haskey(index::FileIndex, key::String) = haskey(getheaders(index), key)
Base.length(index::FileIndex) = length(getmessages(index))

function getone(index::FileIndex, key::AbstractString) 
    val = getheaders(index)[key]
    length(val) !== 1 ? error("Expected 1 value for $key, found $(length(val)) instead") : first(val)
end

function filter_messages(index::FileIndex{T}, args...; kwargs...) where T
    mindexs = filter_messages(getmessages(index), args...; kwargs...)
    unique_headers = build_unique_headers(mindexs)
    FileIndex{T}(index.grib_path, mindexs, unique_headers, index._first_data)
end

function with_messages(f::Function, index::FileIndex, args...; kwargs...) 
    for m in filter_messages(index, args...; kwargs...)
        f(m)
    end
end

enforce_unique_attributes(index::FileIndex, attribute_keys) = enforce_unique_attributes(getheaders(index), attribute_keys)

function get_messages_length(index::FileIndex)
    [length(m) for m in index.messages]
end

"""
Push the values of the `message` headers if they don't exist in the dictionnary `d`
"""
function _add_headers!(d, mind)
    for (k, v) in getheaders(mind)
        ismissing(v) && continue
        if v ∉ d[k]
            push!(d[k], v)
        end
    end
end

function build_unique_headers(mindexs::Vector{<:MessageIndex})
    unique_headers = DefaultDict{AbstractString, Vector{Any}}(() -> Vector{Any}())
    for mi in mindexs
        _add_headers!(unique_headers, mi)
    end
    unique_headers
end
# function _filter_missing!(d)
#     for (k,v) in d
#         missing ∈ v && pop!(d, k)
#     end
# end