function _check4(msg, dict, thing, field, checkingfun)
    if !haskey(dict, field) 
        println(msg, "$thing missing $field")
        return nothing
    end
    x = dict[field]
    checkingfun(x) || println(msg, "bad $thing $field: $x")
end

_check4s(::Missing, fieldfun, thing, msg) = nothing
_check4s(dicts, fieldfun, thing, msg) = for dict in dicts
    ks = keys(dict)
    fields = keys(fieldfun)
    strange = filter(!∈(fields), ks)
    !isempty(strange) && println(msg, "in $thing, I do not recognize: $(join(strange, ", "))")
    for (field, fun) in fieldfun
        _check4(msg, dict, thing, field, fun)
    end
end

_windid(x::Integer) = 1 ≤ x ≤ 5
_windid(_) = false
_windspeed(x::Integer) = 0 ≤ x ≤ 255
_windspeed(_) = false

_starintensity(x::Integer) = 0 ≤ x ≤ 255
_starintensity(_) = false
_starcardinal(x::String) = x ∈ ("SE", "NE", "SW", "NW")
_starcardinal(_) = false
_starradius(x::Integer) = 0 ≤ x ≤ 255
_starradius(_) = false
_starelevation(x::Integer) = 1 ≤ x ≤ 71
_starelevation(_) = false

_milkywayintensity(x::Real) = 0 ≤ x
_milkywayintensity(_) = false
_milkywaycardinal(x::Vector{String}) = length(x) == 2 && (("NE" ∈ x && "SW" ∈ x) || ("NW" ∈ x && "SE" ∈ x))

function _check1(x::Dict)
    msg = IOBuffer()
    haskey(x, "label") || println(msg, "missing label")
    ks = keys(x)
    length(ks) == 1 && println(msg, "does nothing")
    strange = filter(!∈(["label", "stars", "winds", "milky_ways"]), ks)
    !isempty(strange) && println(msg, "I do not recognize: $(join(strange, ", "))")
    _check4s(get(x, "winds", missing), Dict("id" => _windid, "speed" => _windspeed), "wind", msg) 
    _check4s(get(x, "stars", missing), Dict("cardinal" => _starcardinal, "elevation" => _starelevation), "star", msg) 
    _check4s(get(x, "milky_ways", missing), Dict("cardinals" => _milkywaycardinal), "milky_way", msg) 
    return String(take!(msg))
end
_check1(x) = ""

const badchar = ('\\', '/', ':', '*', '?', '"', '<', '>', '|')
_good_name(x) = all(!in(badchar), x)

_checksetups(::TOML.ParserError) = "bad TOML formatting"
function _checksetups(ds)
    isempty(ds) && return "file was empty"
    (haskey(ds, "title") && !isempty(ds["title"])) || return "missing experiment title"
    _good_name(ds["title"]) || return "experiment title may not include: $(join(badchar, " "))"
    (haskey(ds, "experimenters") && !isempty(ds["experimenters"])) || return "missing experimenters' names"
    (haskey(ds, "setups") && !isempty(ds["setups"])) || return "missing setups"
    msgs = _check1.(ds["setups"])
    msg = string(("\nSetup $i:\n$msg" for (i, msg) in enumerate(msgs) if !isempty(msg))...)
    isempty(msg) || return msg
    return ds
    # return Experiment(ds)
end

function checksetups(txt)
    ds = TOML.tryparse(txt)
    return _checksetups(ds)
end

