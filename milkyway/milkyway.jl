using Interpolations, FileIO, Statistics, Cubature, Serialization

img = FileIO.load("milkyway.png")
h, w = size(img)

normx(x) = (x - 1)/(w - 1)*140 + 20
normy(y) = (1 - (y - 1)/(h - 1))*4e6

xy = NTuple{2, Float64}[]
for (x,c) in enumerate(eachcol(img))
    i = findall(≠(img[1]), c)
    if !isempty(i)
        push!(xy, (normx(x), normy(mean(i))))
    end
end

e2i = LinearInterpolation(first.(xy), last.(xy), extrapolation_bc = 0.0)

led_lims = 0.5:1:141.5
led2e(led) = (led - 1)/70*90
el_lims = led2e.(led_lims)

int = map(zip(el_lims[1:end-1], el_lims[2:end])) do (xmin, xmax)
    first(hquadrature(x -> e2i(x), xmin, xmax))
end

# el = mean.(zip(el_lims[1:end-1], el_lims[2:end])) # uneeded

# this is the calibration function.
# TODO: replace this with a real function
# right now it just maxes ourt the intensity
int2uint(x) = 255x/4.362195807446645e6

# this is a vector with 141 elements (0-180° elevation) that should populate the 300 element LED messege vector that is sent to the Arduino
milkyway = int2uint.(int)
serialize("../milkyway_vector", milkyway)
