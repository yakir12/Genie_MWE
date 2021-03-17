const LIGHTSOUT = zeros(UInt8, 5)

struct LED
    ind1::UInt8
    ind2::UInt8
    r::UInt8
    g::UInt8
    b::UInt8
end

LED(i::Integer, r, g, b) = LED(reverse(reinterpret(UInt8, [UInt16(i)]))..., r, g, b)

function star2leds(s::Star)
    ledsperstrip = 150
    deadleds = 9
    liveleds = ledsperstrip - deadleds
    centerled = (liveleds - 1)÷2

    striphalf = Int(s.cardinal)
    base = isodd(striphalf) ?  s.elevation - 1 : liveleds - s.elevation
    secondstrip = striphalf ≥ 3
    extra = secondstrip ? ledsperstrip - 1 : 0
    μ = base + extra
    m = secondstrip ? ledsperstrip - 1 : 0
    M = secondstrip ? ledsperstrip + liveleds - 1 : liveleds - 1
    i1 = max(m, μ - s.radius)
    i2 = min(M, μ + s.radius)
    indices = replace(i1:i2, centerled => centerled + ledsperstrip - 1)
    LED.(indices, s.r, s.g, s.b)
end

function pressed2arduinos(stars::Vector{Star})
    isempty(stars) && return LIGHTSOUT
    msg = UInt8[]
    for star in stars, led in star2leds(star), field in fieldnames(LED)
        push!(msg, getfield(led, field))
    end
    return msg
end

port = nicolas ? "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_757353036313519070B1-if00" : "/dev/serial/by-id/usb-1a86_USB2.0-Serial-if00-port0"
# port = "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_95735353032351F0F0F0-if00"
const LED_SP = LibSerialPort.open(port, 9600)

kill_lights() = encode(LED_SP, LIGHTSOUT)

