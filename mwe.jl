# TODO
# backedup never finishes
# move to skyroom repo etc
# fix the video hell
# disable_record when saved hasn't been pressed yet
# figure out how to do the wind speeds reports: MultiUserApp.jl
# identify and report the issue with the button toggle array not loading without a page refresh
# Do I even need to move everything to the Genie infrastructure with routes and modules etc
# learn how to flash the arduino remotely

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
using COBS

# export start_camera, killcam, getframe, SZ, FPS

const DATADIR = home() / "mnt" / "data"
mkpath(DATADIR)
const nicolas = Base.Libc.gethostname() == "nicolas"
const bucket = nicolas ? "nicolas-cage-skyroom" : "top-floor-skyroom2"

include("types.jl")

include("camera.jl")
include("setuplogs.jl")

include("buttons.jl")
include("check_setups.jl")

include("leds.jl")

nicolas && include("fans.jl")

Base.@kwdef struct SkyRoom <: ReactiveModel
    cameraon::R{Bool} = true
    camera_label::R{String} = "Camera on"
    imageurl::R{String} = IMG_FILE
    kill::R{Bool} = false
    buttons::R{Vector{Dict{Symbol, Any}}} = Dict{Symbol, Any}[]
    pressed::R{Dict{String, Any}} = Dict{String, Any}("label" => "")
    recording::R{Bool} = false
    record_label::R{String} = "Not recording"
    disable_record::R{Bool} = false
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
const cam_timer = Ref(Timer(1.0))

check_on_camera(_) = if process_exited(CAM.process[])
    model.cameraon[] = false
end

function restart()

    close(timer[])
    timer[] = Timer(remove_dead_clients, 1; interval=60)

    cam_timer[] = Timer(check_on_camera, 1; interval = 1)

    on(model.recording) do _
        if !model.cameraon[]
            model.cameraon[] = true
        end
    end

    on(model.cameraon) do ison
        model.camera_label[] = ison ? "Camera on" : "Camera off"
        ison ? play(CAM) : kill(CAM)
    end
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
    on(model.backup) do tf
        if tf
            backup()
            model.backup[] = false
        end
    end
    # onbutton(backup, model.backup)

    on(model.pressed) do d
        setup = Setup(d)
        reset_l()
        update_l.(setup.stars)
        # update_l.(setup.milky_ways)
        fixcenter_l()
        write(LED_SP, LEDS)
        update_l(setup.winds)
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
                              heading("SkyRoom on $(Base.Libc.gethostname())"),
                              row(cell(class="st-module", [
                                                           p(h1(span("", @text(:title)))),
                                                          ])),
                              row(cell(class="st-module", [
                                                           quasar(:img, "", src=:imageurl, :basic, style="height: $(CAM.sz)px; max-width: $(CAM.sz)px"),
                                                           p([toggle("", fieldname = :cameraon, checked__icon="play_arrow", unchecked__icon="stop"), span("", @text(:camera_label))]),
                                                           # """ <img id="frame" src="frame" style="height: $(CAM.sz)px; max-width: $(CAM.sz)px" /> """
                                                          ])),
                              row(cell(class="st-module", [
                                                           p(btn("Kill", @click(:kill), icon = "close", color="negative")),
                                                           p(quasar(:uploader, auto__upload = true, hide__upload__btn = true, label = "Upload Setup file", url = "upload")),
                                                           p(quasar(:btn__toggle, "", @bind("pressed"), color = "secondary", toggle__color="primary", :multiple, options=:buttons))
                                                          ])),
                              row(cell(class="st-module", [
                                                           p([toggle("", fieldname = :recording, checked__icon="fiber_manual_record", unchecked__icon="stop", disabled = :disable_record), span("", @text(:record_label))]),
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

up(8082)
# up(open_browser = true)


