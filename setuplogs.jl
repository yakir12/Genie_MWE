strnow() = string(now())
struct SetupLog
    buffer::Observable{Dict{String, Any}}
    log::Vector{Dict{String, Any}}
    _of::Ref{Observables.ObserverFunction}
    function SetupLog()
        buffer = Observable(Dict{String, Any}())
        log = Dict{String, Any}[]
        _of = on(buffer, weak = true) do x
            x["timestamp"] = now()
            push!(log, x)
        end |> Ref
        off(_of[])
        new(buffer, log, _of)
    end
end

function turnon!(sl)
    turnoff!(sl)
    sl._of[] = on(sl.buffer, weak = true) do x
        x["timestamp"] = now()
        push!(sl.log, x)
    end
    notify!(sl.buffer)
end

function turnoff!(sl)
    off(sl._of[])
    empty!(sl.log)
end

getlog(sl) = sl.log
