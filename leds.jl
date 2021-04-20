const ledsperstrip = 150
deadleds = 9
const liveleds = ledsperstrip - deadleds
const centerled = (liveleds - 1)÷2 + 1
const LEDS = zeros(RGB, 2ledsperstrip)

reset_l() = fill!(LEDS, zero(RGB))

function update_l(s::Star)
    striphalf = Int(s.cardinal)
    base = isodd(striphalf) ?  s.elevation : liveleds - s.elevation + 1
    secondstrip = striphalf ≥ 3
    extra = secondstrip ? (nicolas ? ledsperstrip - 1 : ledsperstrip) : 0 # fix these following lines, they check to see if you are in nicolas and adjust the length of the first strip, it seems like it's one LED short, so the address of all the following LEDs in the second strip are -1.
    μ = base + extra
    m = secondstrip ? (nicolas ? ledsperstrip : ledsperstrip + 1) : 1
    M = secondstrip ? (nicolas ? ledsperstrip + liveleds - 1 : ledsperstrip + liveleds) : liveleds 
    i1 = max(m, μ - s.radius)
    i2 = min(M, μ + s.radius)
    for i in i1:i2
        LEDS[i] = s.color
    end
end

fixcenter_l() = if LEDS[centerled] ≠ zero(RGB)
    LEDS[centerled + ledsperstrip - 1] = LEDS[centerled]
    LEDS[centerled] = zero(RGB)
end

ledports = Dict("eira" => "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_95735353032351F0F0F0-if00", "nicolas" => "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_757353036313519070B1-if00", "sheldon" => "/dev/serial/by-id/usb-1a86_USB2.0-Serial-if00-port0")

# baudrate = nicolas ? 115200 : 9600 # TODO: fix the ardiuino in sheldon
baudrate = 115200
const LED_SP = LibSerialPort.open(ledports[Base.Libc.gethostname()], baudrate, mode = SP_MODE_WRITE)

Base.Tuple(c::RGB) = (red(c), green(c), blue(c))

function kill_lights()
    reset_l()
    for led in LEDS, i in Tuple(led)
        write(LED_SP, reinterpret(UInt8, i))
    end
end

clump(x) = x < 0 ? 0.0 : x > 255 ? 1.0 : x/255

function update_l(m::MilkyWay)
    mw = copy(MILKYWAY)
    mw .*= m.intensity
    map!(clump, mw, mw)
    i1, i2 = Int.(m.cardinals)
    if i1 > i2
        reverse!(mw)
    end
    inds = i1 < 3 ? UnitRange(1,141) : UnitRange(151,150 + 141)
    for (i, j) in enumerate(inds)
        LEDS[j] = RGB{N0f8}(HSV(m.hue, m.saturation, mw[i]))
    end
end

function update_l(m::Calibration)
    LEDS[1:141] .= CALIBRATION
end
