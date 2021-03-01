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

_fanid(x::Int) = 1 ≤ x ≤ 5
_fanid(_) = false
_fanspeed(x::Int) = 0 ≤ x ≤ 255
_fanspeed(_) = false

_starintensity(x::Int) = 0 ≤ x ≤ 255
_starintensity(_) = false
_starcardinal(x::String) = x ∈ ("SE", "NE", "SW", "NW")
_starcardinal(_) = false
_starradius(x::Int) = 0 ≤ x ≤ 300
_starradius(_) = false
_starelevation(x::Int) = 1 ≤ x ≤ 71
_starelevation(_) = false

function _check1(x)
    msg = IOBuffer()
    haskey(x, "label") || println(msg, "missing label")
    ks = keys(x)
    length(ks) == 1 && println(msg, "does nothing")
    strange = filter(!∈(["label", "stars", "fans", "milky_ways"]), ks)
    !isempty(strange) && println(msg, "I do not recognize: $(join(strange, ", "))")
    _check4s(get(x, "fans", missing), Dict("id" => _fanid, "speed" => _fanspeed), "fan", msg) 
    _check4s(get(x, "stars", missing), Dict("intensity" => _starintensity, "cardinal" => _starcardinal, "radius" => _starradius, "elevation" => _starelevation), "star", msg) 
    return String(take!(msg))
end

function checksetups(txt)
    d = TOML.tryparse(txt)
    d isa TOML.ParserError && return "bad TOML formatting"
    isempty(d) && return "file was empty"
    msgs = _check1.(values(d))
    msg = string(("\nButton $btn:\n$msg" for (btn, msg) in zip(keys(d), msgs) if !isempty(msg))...)
    isempty(msg) ? d : msg
end

