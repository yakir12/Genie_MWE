using Serialization
ind2elev(x) = (x - 1)/140*180
lb = 20
ub = 157 #166
M = 255/3
elev2int(x) = lb < x < ub ? round(UInt8, M*(x - lb)/(ub - lb)) : 0x00
inds = 1:141
ints = elev2int.(ind2elev.(inds))
@assert Int.(extrema(filter(!iszero, ints))) == (1, M)

serialize("../calibration_vector", ints)
