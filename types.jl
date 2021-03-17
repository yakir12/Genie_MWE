@enum Cardinal NE=1 SW=2 SE=3 NW=4

struct Star
    cardinal::Cardinal
    elevation::Int
    intensity::Int
    radius::Int
end

_getcardinal(txt) = Cardinal(findfirst(==(txt), string.(instances(Cardinal))))

Star(d::Dict) = Star(_getcardinal(d["cardinal"]), d["elevation"], d["intensity"], get(d, "radius", 0))

struct Wind
    id::Int
    speed::Int
end

Wind(d::Dict) = Wind(d["id"], d["speed"])

struct MilkyWay
    intensity::Int
    cardinal::String
    brightest::String
    contrast::Float64
end

MilkyWay(d::Dict) = MilkyWay(d["intensity"], d["cardinal"], d["brightest"], d["contrast"])

struct Setup
    label::String
    stars::Vector{Star}
    winds::Vector{Wind}
    milky_ways::Vector{MilkyWay}
end

Setup(d::Dict) = Setup(d["label"], 
                         haskey(d, "stars") ? Star.(d["stars"]) : Star[], 
                         haskey(d, "winds") ? Wind.(d["winds"]) : Wind[], 
                         haskey(d, "milky_ways") ? MilkyWay.(d["milky_ways"]) : MilkyWay[])

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
