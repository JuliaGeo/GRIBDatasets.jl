"""
    const GRIB_STEP_UNITS_TO_SECONDS

Array used to convert the grib step units to seconds. 
Taken from eccodes `stepUnits.table`.
"""
const GRIB_STEP_UNITS_TO_SECONDS = [
    60,
    3600,
    86400,
    missing,
    missing,
    missing,
    missing,
    missing,
    missing,
    missing,
    10800,
    21600,
    43200,
    1,
    900,
]


"""
    from_grib_date_time(date::Int, time::Int; epoch::DateTime=DEFAULT_EPOCH)
Seconds from epoch to the given date and time.
"""
function from_grib_date_time(date::Int, time::Int; epoch::DateTime=DEFAULT_EPOCH)::Int
    hour = time ÷ 100
    minute = time % 100
    year = date ÷ 10000
    month = date ÷ 100 % 100
    day = date % 100

    data_datetime = DateTime(year, month, day, hour, minute)

    return Dates.value(Dates.Second(data_datetime - epoch))
end

function from_grib_date_time(message::GRIB.Message; date_key="dataDate", time_key="dataTime", epoch::DateTime=DEFAULT_EPOCH)::Union{Int,Missing}
    if !haskey(message, date_key) || !haskey(message, time_key)
        return missing
    end

    date = message[date_key]
    time = message[time_key]

    return from_grib_date_time(date, time, epoch=epoch)
end

function to_grib_date_time(args...; kwargs...)
    throw(ErrorException("Unimplemented"))
end

"""
    from_grib_step(message::GRIB.Message, step_key::String="endStep", step_unit_key::String="stepUnits")
Returns the `step_key` value in hours.
"""
function from_grib_step(message::GRIB.Message, step_key::String="endStep", step_unit_key::String="stepUnits")::Float64
    to_seconds = GRIB_STEP_UNITS_TO_SECONDS[message[step_unit_key] + 1]
    return message[step_key] * to_seconds / 3600.0
end

function to_grib_step(args...; kwargs...)
    throw(ErrorException("Unimplemented"))
end

"""
    from_grib_month
Returns the integer seconds from the epoch to the verifying month value in the
GRIB message.
"""
function from_grib_month(message::GRIB.Message, verifying_month_key::String="verifyingMonth", epoch::DateTime=DEFAULT_EPOCH)::Union{Int,Missing}
    if !haskey(message, verifying_month_key)
        return missing
    end

    date = message[verifying_month_key]
    year = date ÷ 100
    month = date % 100
    data_datetime = DateTime(year, month)

    return Dates.value(Dates.Second(data_datetime - epoch))
end

"""
Returns a pair of `(dims, data)` based on the type of input
"""
function build_valid_time end

"""
```jldoctest
julia> GDS.build_valid_time(10, 10)
((), 36010)
```
"""
function build_valid_time(time::Int, step::Int)::Tuple{Tuple{},Int64}
    step_s = step * 3600

    data = time + step_s
    dims = ()

    return dims, data
end

"""
```jldoctest
julia> GDS.build_valid_time([10], 10)
(("time",), [36010])
```
"""
function build_valid_time(time::Array{Int,1}, step::Int)::Tuple{Tuple{String},Array{Int64,1}}
    step_s = step * 3600

    data = time .+ step_s
    dims = ("time",)

    return dims, data
end

"""
```jldoctest
julia> GDS.build_valid_time(1, [10])
(("step",), [36001])
```
"""
function build_valid_time(time::Int, step::Array{Int,1})::Tuple{Tuple{String},Array{Int64,1}}
    step_s = step * 3600

    data = time .+ step_s
    dims = ("step",)

    return dims, data
end

"""
```jldoctest
julia> GDS.build_valid_time([10, 10], [10, 10])
(("time", "step"), [36010 36010; 36010 36010])
```

```jldoctest
julia> GDS.build_valid_time([10], [10])
((), 36010)
```
"""
function build_valid_time(time::Array{Int,1}, step::Array{Int,1})
    step_s = step * 3600

    if length(time) == 1 && length(step) == 1
        return build_valid_time(time[1], step[1])
    end

    data = time' .+ step_s
    dims = ("time", "step")
    return dims, data
end

"""
Dictionary which maps a key to a conversion method. The first function is the
'to' conversion, the second is 'from'.

Currently converts:

```
    "time" => (from_grib_date_time, to_grib_date_time)

    "valid_time" => (
        message -> from_grib_date_time(message, date_key="validityDate", time_key="validityTime"),
        message -> to_grib_date_time(message, date_key="validityDate", time_key="validityTime"),
    )

    "verifying_time" => (from_grib_month, m -> throw(ErrorException("Unimplemented")))

    "indexing_time" => (
        message -> from_grib_date_time(message, date_key="indexingDate", time_key="indexingTime"),
        message -> to_grib_date_time(message, date_key="indexingDate", time_key="indexingTime"),
    )
```

# Example

A GRIB message containing `20160501` as the date key and `0` as the time key
would end up calling:

```jldoctest
julia> GDS.COMPUTED_KEYS["time"][1](20160501, 0)
1462060800
```
"""
COMPUTED_KEYS = Dict(
    "time" => (
        from_grib_date_time, 
        to_grib_date_time
        ),
    "valid_time" => (
        message -> from_grib_date_time(message, date_key="validityDate", time_key="validityTime"),
        message -> to_grib_date_time(message, date_key="validityDate", time_key="validityTime"),
        ),
    "verifying_time" => (
        from_grib_month, 
        m -> throw(ErrorException("Unimplemented"))
        ),
    "indexing_time" => (
        message -> from_grib_date_time(message, date_key="indexingDate", time_key="indexingTime"),
        message -> to_grib_date_time(message, date_key="indexingDate", time_key="indexingTime"),
        ),
)

"""
    read_message(message::GRIB.Message, key::String)
Read a specific key from a GRIB.jl message. Attempts to convert the raw value
associated with that key using the [`COMPUTED_KEYS`](@ref COMPUTED_KEYS) mapping
to `from_grib_*` functions.
"""
function read_message(message::GRIB.Message, key::String)
    value = missing

    if key in keys(COMPUTED_KEYS)
        value = COMPUTED_KEYS[key][1](message)
    end

    if ismissing(value)
        value = haskey(message, key) ? message[key] : missing
    end

    value = value isa Array ? Tuple(value) : value

    return value
end

"""
    MessageIndex

Stored information about a GRIB message. The keys can be accessed with `getindex`. The message offset and length are stored as property of the struct.
"""
struct MessageIndex
    headers::Dict{String, Any}
    offset::Int64
    length::Int64
end

"""
    MessageIndex(message::GRIB.Message; index_keys = ALL_KEYS)

Read a GRIB `message` and store the requested `index_keys` in memory as a [`MessageIndex`](@ref). 
```jldoctest; setup = :(using GRIB)
f = GribFile(example_file) 
message = first(f)
mind = GDS.MessageIndex(message)
destroy(f)
mind["name"]

# output
"Geopotential"
```
"""
function MessageIndex(message::GRIB.Message; index_keys = ALL_KEYS)
    values = read_message.(Ref(message), index_keys)
    offset = Int(message["offset"])
    length = message["totalLength"]

    headers = Dict(k => v for (k,v) in zip(index_keys, values))
    MessageIndex(headers, offset, length)
end

getoffset(mindex::MessageIndex) = mindex.offset
getheaders(mindex::MessageIndex) = mindex.headers
Base.length(mindex::MessageIndex) = mindex.length
Base.getindex(mindex::MessageIndex, args...) = getindex(getheaders(mindex), args...)
Base.haskey(mindex::MessageIndex, key) = haskey(getheaders(mindex), key)

Base.show(io::IO, mime::MIME"text/plain", mind::MessageIndex) = show(io, mime, getheaders(mind))

function filter_messages(mindexs::Vector{<:MessageIndex}, k::AbstractString, v)
    filter(mi -> getheaders(mi)[k] == v, mindexs)
end


function filter_messages(mindexs::Vector{<:MessageIndex}; query...)
    ms = deepcopy(mindexs)
    for (k, v) in query
        ms = filter_messages(ms, string(k), v)
    end
    ms
end

function get_offsets(mindexs::Vector{<:MessageIndex}, key, val)
    getoffset.(filter(x -> getheaders(x)[key] == val, mindexs))
end