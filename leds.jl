# const brightness = 1
const ledport = nicolas ? "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_757353036313519070B1-if00" : "/dev/serial/by-id/usb-1a86_USB2.0-Serial-if00-port0"
# const ledport = "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_95735353032351317061-if00"

struct LED
    ind1::UInt8
    ind2::UInt8
    r::UInt8
    g::UInt8
    b::UInt8
end

LED(i::Int, r, g, b) = LED(reinterpret(UInt8, [UInt16(i)])..., r, g, b)

function star2leds(s::Star)
    ledsperstrip = 150
    deadleds = 9
    liveleds = ledsperstrip - deadleds
    centerled = (liveleds - 1)÷2

    striphalf = Int(s.cardinal)
    base = isodd(striphalf) ?  s.elevation - 1 : liveleds - s.elevation
    secondstrip = Int(striphalf ≥ 3)
    extra = secondstrip*ledsperstrip
    μ = base + extra
    m = secondstrip*ledsperstrip
    M = (1 + secondstrip)*ledsperstrip - 1
    i1 = max(m, μ - s.radius)
    i2 = min(M, μ + s.radius)
    indices = replace(i1:i2, centerled => centerled + ledsperstrip)
    LED.(indices, s.r, s.g, s.b)
end

function pressed2arduinos(stars::Vector{Star})
    isempty(stars) && return zeros(UInt8, 5)
    msg = UInt8[]
    for star in stars, led in star2leds(star), field in fieldnames(LED)
        push!(msg, getfield(led, field))
    end
    return msg
end
pressed2arduinos(setup::Setup) = pressed2arduinos(setup.stars)
pressed2arduinos(d::Dict) = pressed2arduinos(Setup(d))

mutable struct LEDArduino <: AbstractArduino
    port::String
    sp::SerialPort
    pwm::Observable{Vector{UInt8}}
    function LEDArduino()
        sp = LibSerialPort.open(ledport, baudrate)
        pwm = Observable(UInt8[0, 0])
        on(pwm) do x
            encode(sp, x)
        end
        new(ledport, sp, pwm)
    end
end

# const ledarduino = (; pwm = Observable(UInt8[]))
const ledarduino = LEDArduino()
