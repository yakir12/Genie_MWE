function toint(msg)
    y = zero(UInt32)
    for c in msg
        y <<= 8
        y += c
    end
    return y
end

top_rpm = 12650
const t4 = 15000000
const shortest_t = t4/1.1top_rpm

t2rpm(t) = t < shortest_t ?  missing : t4/t

function getrpm(c, sp) 
    msg = loack(c) do
        sp_flush(sp, SP_BUF_OUTPUT)
        decode(sp) 
    end
    t2rpm.(toint.(Iterators.partition(msg, 4)))
end

struct Fan
    sp::SerialPort
    c::ReentrantLock
    rpm::Ref{NTuple{3, Float64}}
    function Fan(port::String) 
        sp = LibSerialPort.open.(port, 9600)
        c = ReentrantLock()
        rpm = Ref(Tuple(rand(3)))
        @async while isopen(sp)
            rpm[] = getrpm(c, sp)
            sleep(1)
        end
        new(sp, c, rpm)
    end
end

getrpm(f::Fan) = f.rpm[]

setpwm(f::Fan, pwm::UInt8) = lock(f.c) do 
    for _ in 1:3
        sp_flush(f.sp, SP_BUF_INPUT)
        encode(f.sp, pwm)
        sleep(0.01)
    end
end


killfan(f::Fan) = setpwm(f, 0x00)

fanports = ["/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_957353530323510141D0-if00", "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_95635333930351917172-if00", "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_95735353032351010260-if00", "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_55838323435351213041-if00", "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_957353530323514121D0-if00"]

const FANS = Tuple(Fan.(fanports))
Fans = NTuple{5, Fan}

killfans() = foreach(killfan, FANS)

update_l(w::Winds) = foreach(setpwm, FANS, w.speeds)

getrpms() = join(Iterators.flatten(getrpm.(FANS)), ",")

const FAN_IO = Ref(open(tempname(), "w"))
close(FAN_IO[])

function recordfans(folder)
    FAN_IO[] = open(folder / "fans.csv", "w")
    println(FAN_IO[], "time,", join([join(["fan$(i)_speed$j" for j in 1:3], ",") for i in 1:5], ","))
    @async while isopen(FAN_IO[])
        println(FAN_IO[], now(), ",", getrpms())
        sleep(1)
    end
end

#=
# tosecond(t::T) where {T <: TimePeriod}= t/convert(T, Second(1))
# sincestart(t) = tosecond(t - t₀[])

function toint(msg)
    y = zero(UInt32)
    for c in msg
        y <<= 8
        y += c
    end
    return y
end

function getrpm(t)
    t4 = 15000000
    shortest_t = t4/1.1top_rpm[]
    t < shortest_t ?  missing : t4/t
end

function set_pwm!(sp, c, pwm)
    lock(c) do
        sp_flush(sp, SP_BUF_INPUT)
        encode(sp, pwm)
    end
end

function update_rpm!(sp, c, pwm, msg, rpm)
    if pwm[] > 19
        lock(c) do 
            sp_flush(sp, SP_BUF_OUTPUT)
            decode!(msg, sp, 12) 
        end
        for (i, x) in enumerate(Iterators.partition(msg, 4))
            rpm[i] = getrpm(toint(x))
        end
    else
        fill!(rpm, 0.0)
    end
end


struct FanArduino <: AbstractArduino
    id::Int
    c::ReentrantLock
    sp::SerialPort
    msg::Vector{UInt8}
    rpm::Vector{Union{Missing, Float64}}
    pwm::Observable{UInt8}
    function FanArduino(id::Int, port::String)
        c = ReentrantLock()
        sp = LibSerialPort.open(port, baudrate[])
        pwm = Observable(0x00)
        on(pwm) do x
            set_pwm!(sp, c, x)
        end
        msg = Vector{UInt8}(undef, 12)
        rpm = Vector{Float64}(undef, 3)
        new(id, c, sp, msg, rpm, pwm)
    end
end

update_rpm!(a::FanArduino) = update_rpm!(a.sp, a.c, a.pwm, a.msg, a.rpm)

get_rpm(a::FanArduino) = a.rpm

struct AllWind
    arduinos::Vector{FanArduino}
    io::IOStream
    framerate::Int
    function AllWind(arduinos::Vector{FanArduino}, framerate::Int)
        io = open(tempname(), "w")
        close(io)
        new(arduinos, io, framerate)
    end
end

=##=function get_rpms(allwind::AllWind)
    @sync for a in allwind.arduinos
        @async update_rpm!(a)
    end
    now() => get_rpm.(allwind.arduinos)
end=##=

function record(allwind::AllWind, folder)
    isopen(allwind.io) && close(allwind.io)
    allwind.io = open(folder / "fans.csv", "w")
    println(allwind.io, "time,", join([join(["fan$(a.id)_speed$j" for j in 1:3], ",") for a in allwind.arduinos], ","))
    @async while isopen(allwind.io)
        println(allwind.io, now(), ",",join(Iterators.flatten(get_rpm.(allwind.arduinos)), ","))
        sleep(1/allwind.framerate)
    end
end

Base.isopen(allwind::AllWind) = all(isopen, allwind.arduinos)
Base.close(allwind::AllWind) = close.(allwind.arduinos)

fanports = ["/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_957353530323510141D0-if00", "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_95635333930351917172-if00", "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_95735353032351010260-if00", "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_55838323435351213041-if00", "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_957353530323514121D0-if00"]
fanarduinos = FanArduino.(fanports, 1:5)
allwind = AllWind(fanarduinos, 1)

function update_l(w::Wind)
=#
