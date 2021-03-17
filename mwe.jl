# TODO
# when kill is pressed, it would be good if the toggle buttons reset somehow
# there is a weird shift in leds, fix thecenter at least
# sort out the global/const thing, especially with the arduino ports getting stuck
# identify and report the issue with the button toggle array not loading without a page refresh
# maybe figure out how to avoide the cameraon Observable, it isn't really used here at all
#
# Important:
# mount and try everything on the RPIs for real (how to connect it to the picam)
# connect all the LED and Arduino mechanism when the buttons are done
# And hard:
# figure out how to do the wind speeds reports: MultiUserApp.jl
#
# Good:
# Do I even need to move everything to the Genie infrastructure with routes and modules etc
# can/should I use a quasar image instead of <img />
# And hard:
# put the setInterval is in the right place

import Base.kill

using Stipple, StippleUI
using Genie.Renderer.Html
using TOML
using Dates
using FilePathsBase
using FilePathsBase: /
using Tar
using DataStructures

using HTTP
using FFMPEG_jll, ImageMagick, FileIO
using LibSerialPort

# export start_camera, killcam, getframe, SZ, FPS

const DATADIR = home() / "mnt" / "data"
mkpath(DATADIR)
const nicolas = Base.Libc.gethostname() == "nicolas"
const bucket = nicolas ? "nicolas-cage-skyroom" : "top-floor-skyroom2"

include("cobs.jl")
include("types.jl")

include("camera.jl")
include("setuplogs.jl")

include("buttons.jl")
include("check_setups.jl")

include("abstractarduino.jl")
include("leds.jl")

# Base.@kwdef mutable struct SkyRoom <: ReactiveModel
#     kill::R{Bool} = false
#     buttons::R{Vector{Dict{Symbol, Any}}} = Dict{Symbol, Any}[]
#     pressed::R{Dict{String, Any}} = Dict{String, Any}()
#     recording::R{Bool} = false
#     record_label::R{String} = "Not recording"
#     timestamp::R{DateTime} = now()
#     experiment::R{String} = "Unknown"
#     experimenters::R{Vector{String}} = String[]
#     beetleid::R{String} = ""
#     comment::R{String} = ""
#     folder::R{PosixPath} = p""
#     save::R{Bool} = false
#     disable_save::R{Bool} = true
#     backup::R{Bool} = false
#     backedup::R{Float64} = 0.0
#     msg::R{String} = ""
# end

Base.@kwdef struct SkyRoom <: ReactiveModel
    cameraon::R{Bool} = true
    imageurl::R{String} = IMG_FILE
    kill::R{Bool} = false
    buttons::R{Vector{Dict{Symbol, Any}}} = Dict{Symbol, Any}[]
    pressed::R{Dict{String, Any}} = Dict{String, Any}("label" => "")
    recording::R{Bool} = false
    record_label::R{String} = "Not recording"
    timestamp::R{DateTime} = now()
    title::R{String} = "Unknown"
    experimenters::R{Vector{String}} = String[]
    beetleid::R{String} = ""
    comment::R{String} = ""
    folder::R{PosixPath} = p""
    save::R{Bool} = false
    disable_save::R{Bool} = true
    backup::R{Bool} = false
    backedup::R{Float64} = 0.0
    msg::R{String} = ""
end

# struct SkyRoom <: ReactiveModel
#     kill::R{Bool}
#     buttons::R{Vector{Dict{Symbol, Any}}}
#     pressed::R{Dict{String, Any}}
#     recording::R{Bool}
#     record_label::R{String}
#     timestamp::R{DateTime}
#     experiment::R{String}
#     experimenters::Ref{Vector{String}}
#     beetleid::R{String}
#     comment::R{String}
#     folder::Ref{PosixPath}
#     save::R{Bool}
#     disable_save::R{Bool}
#     backup::R{Bool}
#     backedup::R{Float64}
#     msg::R{String}
#     setuplog::SetupLog
#
#     function SkyRoom()
#         kill = R(false)
#         buttons = R(Dict{Symbol, Any}[])
#         pressed = R(Dict{String, Any}())
#         recording = R(false)
#         record_label = R("")
#         timestamp = R(now())
#         experiment = R("Unknown")
#         experimenters = Ref(String[])
#         beetleid = R("")
#         comment = R("")
#         folder = Ref(p"")
#         save = R(false)
#         disable_save = R(true)
#         backup = R(false)
#         backedup = R(0.0)
#         msg = R("")
#
#         onany(experiment, timestamp) do experiment, timestamp
#             folder[] = DATADIR / string(experiment, "_", timestamp)
#         end
#         on(recording) do tf
#             record_label[] = tf ? "Recording" : "Not recording"
#         end
#
#         new(kill, buttons, pressed, recording, record_label, timestamp, experiment, experimenters, beetleid, comment, folder, save, disable_save, backup, backedup, msg)
#     end
# end

function remove_dead_clients(timer)
    for (ch, clients) in Genie.WebChannels.subscriptions()
        for cl in clients
            try
                Genie.WebChannels.message(cl, "")
            catch ex
                @info "removing dead client: $cl from $ch"
                Genie.WebChannels.pop_subscription(cl, ch)
            end
        end
    end
end


const SETLOG = SetupLog()
const CAM = Camera()
const model = Stipple.init(SkyRoom(), debounce=1) 
const timer = Ref(Timer(1.0))

function restart()

    close(timer[])
    timer[] = Timer(remove_dead_clients, 1; interval=60)

    # on(model.cameraon) do ison
    #     ison ? play(CAM) : kill(CAM)
    # end
    onany(model.title, model.timestamp) do title, timestamp
        model.folder[] = DATADIR / string(title, "_", timestamp)
    end
    on(model.recording) do tf
        model.record_label[] = tf ? "Recording" : "Not recording"
    end
    connect!(SETLOG.buffer, model.pressed)
    on(toggle_record, model.recording)
    onbutton(killall, model.kill)
    onbutton(save, model.save)
    onbutton(backup, model.backup)

    on(model.pressed) do d
        setup = Setup(d)
        msg = pressed2arduinos(setup.stars)
        encode(LED_SP, msg)
    end
end

Stipple.js_methods(model::SkyRoom) = """
updateimage: function () { 
this.imageurl = "frame/" + new Date().getTime();
},
startcamera: function () { 
this.cameratimer = setInterval(this.updateimage, $(1000 ÷ CAM.fps));
},
stopcamera: function () { 
clearInterval(this.cameratimer);
},
badtoml: function () {
this.\$q.notify({message: SkyRoom.msg, color: 'negative'});
}
"""

Stipple.js_created(model::SkyRoom) = """
if (this.cameraon) { this.startcamera() };
"""
# this.\$q.dark.set(true);

Stipple.js_watch(model::SkyRoom) = """
cameraon: function (newval, oldval) { 
this.stopcamera()
if (newval) { this.startcamera() }
},
msg: function () {
this.badtoml();
}
"""

function ui()
    m = dashboard(vm(model), [
                              heading("SkyRoom"),
                              row(cell(class="st-module", [
                                                           p(h1(span("", @text(:title)))),
                                                          ])),
                              row(cell(class="st-module", [
                                                           quasar(:img, "", src=:imageurl, :basic, style="height: $(CAM.sz)px; max-width: $(CAM.sz)px"),
                                                           # p(toggle("Camera on", fieldname = :cameraon)),
                                                           # """ <img id="frame" src="frame" style="height: $(CAM.sz)px; max-width: $(CAM.sz)px" /> """
                                                          ])),
                              row(cell(class="st-module", [
                                                           p(btn("Kill", @click(:kill), icon = "close", color="negative")),
                                                           p(quasar(:uploader, accept = ".toml", auto__upload = true, hide__upload__btn = true, label = "Upload Setup file", url = "upload")),
                                                           p(quasar(:btn__toggle, "", @bind("pressed"), color = "secondary", toggle__color="primary", :multiple, options=:buttons))
                                                          ])),
                              row(cell(class="st-module", [
                                                           p([toggle("", fieldname = :recording, checked__icon="fiber_manual_record", unchecked__icon="stop"), span("", @text(:record_label))]),
                                                           p(["Beetle ID ", input("", label = "ID", placeholder="Type in the ID of the beetle", @bind(:beetleid))]),
                                                           p(["Comment ", input("", placeholder="Type in any comments", @bind(:comment), :autogrow)]),
                                                           p(btn("Save", @click(:save), disabled = :disable_save, icon = "save", color="primary")),
                                                           p(btn("Backup", "", @click(:backup), icon = "cloud_upload", percentage = :backedup, loading = :backup, color="primary")),
                                                          ]))
                             ], title = "SkyRoom")

    return html(m)
end

route("/", ui)

route(snap, "frame/:tmstmp")

btn_opt(b) = Dict(:label => b["label"], :value => b)

_try2update_buttons(msg::String) = (model.msg[] = msg)
function _try2update_buttons(x::Dict)
    model.title[] = x["title"]
    model.experimenters[] = x["experimenters"]
    model.buttons[] = btn_opt.(x["setups"])
end


route("upload", method = POST) do
    files = Genie.Requests.filespayload() # type: Dict{String, Genie.Input.HttpFile}
    isempty(files) && (model.msg[] = "No file uploaded")
    length(files) > 1 && (model.msg[] = "Only one file at a time")
    p = only(values(files))
    d = checksetups(String(p.data))
    _try2update_buttons(d)
end

Genie.config.server_host = "0.0.0.0"
# Genie.config.server_host = "127.0.0.1"

restart()

up()
# up(open_browser = true)


