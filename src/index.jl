using DataStructures

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

    "We need to keep the offsets of all the messages of the file for further seeking."
    _all_offsets::Vector{Int}
end
getheaders(index::FileIndex) = index.unique_headers

"""
    FileIndex(grib_path::String; index_keys = ALL_KEYS, filter_by_values = Dict())

Construct a [`FileIndex`](@ref) for the file `grib_path`, storing only the keys in `index_keys`.
It is possible to read only specific values by specifying them in `filter_by_values`.
The values of the headers can be accessed with `getindex`.
"""
function FileIndex(grib_path::String; index_keys = ALL_KEYS, filter_by_values = Dict())
    messages = MessageIndex[]
    datatype = nothing
    fdata = []
    unique_headers = DefaultDict{AbstractString, Vector{Any}}(() -> Vector{Any}())

    f = if isempty(filter_by_values)
        GribFile(grib_path)
    else
        ind = Index(grib_path, keys(filter_by_values)...)
        for (k, v) in filter_by_values
            select!(ind, k, v)
        end
        ind
    end
    try
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
    catch
        rethrow()
    finally
        destroy(f)
    end

    # This is quite inconvenient and unefficient, since we have to go trough all the file
    # even when we want to filter the file. But I couldn't see a better way. It would be
    # nice to be able to seek through the GRIB files with knowing the offset of the message!
    _all_offsets = if isempty(filter_by_values)
        get_offsets(messages)
    else
        get_offsets(grib_path)
    end

    FileIndex{datatype}(grib_path, messages, unique_headers, fdata, _all_offsets)
end

function Base.show(io::IO, mime::MIME"text/plain", index::FileIndex) 
    println(io, "$(typeof(index)) with $(length(index)) messages")
    println(io, "Headers summary:")
    show(io, mime, getheaders(index))
end

function get_offsets(grib_path::AbstractString)
    offsets = Int64[]
    GribFile(grib_path) do f
        for m in f
            push!(offsets, m["offset"])
        end
    end
    return offsets
end

get_offsets(index::FileIndex) = get_offsets(index.messages)

getmessages(index::FileIndex) = index.messages
Base.getindex(index::FileIndex, key::String) = getheaders(index)[key]
Base.haskey(index::FileIndex, key::String) = haskey(getheaders(index), key)

"""
    length(index::FileIndex)
The number of messages in the index.
"""
Base.length(index::FileIndex) = length(getmessages(index))

"""
    getone(index::FileIndex, key::AbstractString)
Check if only one value exists in the `index` at the specified ´key´ and return the value.
"""
function getone(index::FileIndex, key::AbstractString) 
    val = getheaders(index)[key]
    length(val) !== 1 ? error("Expected 1 value for $key, found $(length(val)) instead") : first(val)
end

missing_value(index::FileIndex) = getone(index, "missingValue")

function build_valid_time(index::FileIndex)
    build_valid_time(identity.(index["valid_time"]), identity.(index["step"]))
end

"""
    filter_messages(index::FileIndex{T}, args...; kwargs...)
Filter the messages in the `index` and return a new updated index. The filtering keys must be expressed as keyword arguments pair.

```jldoctest
index = FileIndex(example_file)

filtered = GRIBDatasets.filter_messages(index, shortName = "z", number = 1)
length(filtered)

# output
8
```
"""
function filter_messages(index::FileIndex{T}, args...; kwargs...) where T
    mindexs = filter_messages(getmessages(index), args...; kwargs...)
    unique_headers = build_unique_headers(mindexs)
    FileIndex{T}(index.grib_path, mindexs, unique_headers, index._first_data, index._all_offsets)
end

function with_messages(f::Function, index::FileIndex, args...; kwargs...) 
    for m in filter_messages(index, args...; kwargs...)
        f(m)
    end
end

# enforce_unique_attributes(index::FileIndex, attribute_keys) = enforce_unique_attributes(getheaders(index), attribute_keys)

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

_only(vec) = try 
    only(vec) 
catch e
    e isa ArgumentError ? vec : rethrow()
end
"""
    get_values_from_filtered(index, key, tocheck)
For each `index` values in `key`, give the values in `tocheck` related with it.

```jldoctest
index = FileIndex(example_file)

GDS.get_values_from_filtered(index, "cfVarName", "level")

# output
Dict{SubString{String}, Vector{Any}} with 2 entries:
  "t" => [500, 850]
  "z" => [500, 850]
```
"""
function get_values_from_filtered(index, key, tocheck)
    res = map(index[key]) do varname
        kwargs = NamedTuple((Symbol(key) => varname,))
        findex = filter_messages(index; kwargs...)
        varname => findex[tocheck]
    end
    return Dict(res...)
end