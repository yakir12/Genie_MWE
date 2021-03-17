const ledsperstrip = 150
deadleds = 9
const liveleds = ledsperstrip - deadleds
const centerled = (liveleds - 1)÷2 + 1
const LEDS = zeros(UInt8, 2ledsperstrip)

reset_l() = fill!(LEDS, 0x00)

function update_l(s::Star)
    striphalf = Int(s.cardinal)
    base = isodd(striphalf) ?  s.elevation : liveleds - s.elevation + 1
    secondstrip = striphalf ≥ 3
    extra = secondstrip ? ledsperstrip -1 : 0
    μ = base + extra
    m = secondstrip ? ledsperstrip : 1
    M = secondstrip ? ledsperstrip + liveleds - 1 : liveleds 
    i1 = max(m, μ - s.radius)
    i2 = min(M, μ + s.radius)
    for i in i1:i2
        LEDS[i] = s.intensity
    end
end

fixcenter_l() = if LEDS[centerled] > 0
    LEDS[centerled + ledsperstrip - 1] = LEDS[centerled]
    LEDS[centerled] = 0x00
end

port = nicolas ? "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_757353036313519070B1-if00" : "/dev/serial/by-id/usb-1a86_USB2.0-Serial-if00-port0"
# port = "/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_95735353032351F0F0F0-if00"
const LED_SP = LibSerialPort.open(port, 9600)

function kill_lights()
    reset_l()
    encode(LED_SP, LEDS)
end
