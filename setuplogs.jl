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

const SETLOG = SetupLog()

function turnon!()
    turnoff!()
    SETLOG._of[] = on(SETLOG.buffer, weak = true) do x
        x["timestamp"] = now()
        push!(SETLOG.log, x)
    end
    SETLOG.buffer[] = SETLOG.buffer[]
end

function turnoff!()
    off(SETLOG._of[])
    empty!(SETLOG.log)
end

getlog() = SETLOG.log
