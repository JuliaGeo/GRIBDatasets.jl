using DataStructures


export FileIndex

"""
Store for indices of a GRIB file
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