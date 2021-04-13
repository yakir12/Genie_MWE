@enum Cardinal NE=1 SW=2 SE=3 NW=4

struct Star
    cardinal::Cardinal
    elevation::Int
    color::RGB{N0f8}
    radius::Int
end

_getcardinal(txt) = Cardinal(findfirst(==(txt), string.(instances(Cardinal))))

_getcolor(d) = haskey(d, "intensity") ? RGB{N0f8}(0, d["intensity"]/255, 0) : RGB{N0f8}((d["rgb"]/255)...) 

Star(d::Dict) = Star(_getcardinal(d["cardinal"]), d["elevation"], _getcolor(d), get(d, "radius", 0))

struct MilkyWay
    intensity::Float64
    hue::Int # Hue in [0,360)
    saturation::Float64 # Saturation in [0,1]
    cardinals::Tuple{Cardinal, Cardinal}
end

MilkyWay(d::Dict) = MilkyWay(get(d, "intensity", 1.0), get(d, "hue", 0), get(d, "saturation", 0.0), Tuple(_getcardinal.(d["cardinals"])))

struct Calibration end

Calibration(d::Dict) = Calibration()

struct Winds
    speeds::NTuple{5, UInt8}
end

function Winds(ds::Vector)
    winds = zeros(UInt8, 5)
    for d in ds
        i = d["id"]
        winds[i] = d["speed"]
    end
    return Winds(NTuple{5, UInt8}(winds))
end

struct Setup
    label::String
    stars::Vector{Star}
    winds::Winds
    milky_ways::Vector{MilkyWay}
    calibrations::Vector{Calibration}
end

Setup(d::Dict) = Setup(d["label"],
                       haskey(d, "stars") ? Star.(d["stars"]) : Star[Star(NE, 1, 0, 0)], 
                       haskey(d, "winds") ? Winds(d["winds"]) : Winds(ntuple(zero, 5)), 
                       haskey(d, "milky_ways") ? MilkyWay.(d["milky_ways"]) : MilkyWay[],
                       haskey(d, "calibrations") ? Calibration.(d["calibrations"]) : Calibration[])

# Setup() = Setup("", Star[], Wind[], MilkyWay[])


# struct Experiment
#     title::String
#     experimenters::Vector{String}
#     setups::Vector{Setup}
# end
#
# Experiment(d::Dict) = Experiment(d["title"], d["experimenters"], Setup.(d["setups"]))
#
# Experiment() = Experiment("Undefined", String[], Setup[])
#
