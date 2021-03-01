strnow() = string(now())
struct SetupLog
    buffer::Observable{String}
    log::Dict{String, String}
    of::Ref{Observables.ObserverFunction}
    function SetupLog()
        buffer = Observable{String}("")
        log = Dict{String, String}()
        of = on(buffer, weak = true) do x
            log[strnow()] = x
        end |> Ref
        new(buffer, log, of)
    end
end

function turnon!(s::SetupLog)
    s.of[] = on(s.buffer, weak = true) do x
        s.log[strnow()] = x
    end
    s.buffer[] = s.buffer[]
end

function turnoff!(s::SetupLog)
    off(s.of[])
    empty!(s.log)
end
