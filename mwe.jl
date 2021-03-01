# TODO
# implement js_methods correctly so that the notify mechnism works
# put a bunch of notifys everywhere
# try to implement the same thing with the upload button so it shows actual progress
# implement js_methods correctly so that the setInterval is in the right place
# manage to use the grouped buttons thing so that you can create all the buttons when a csv file is uploaded
# connect all the LED and Arduino mechanism when the buttons are done
# either fix the termination problem of the ffmpeg with saving the video file + pipe, or write to disk each time
# mount and try everything on the RPIs for real (how to connect it to the picam)
# maybe improve on the readpngdata function
# figure out how to connect a button in quasar to a function in Julia without using the silly flipon
# move everything to the Genie infrastructure with routes and modules etc
# can/should I use a quasar image instead of <img />
# have a try catch in the frame route incase the image can't be read with some white background or the previous image or some such





import Base.kill

using Stipple, StippleUI
using Genie.Renderer.Html
using HTTP
using FFMPEG_jll, ImageMagick, FileIO
using TOML
using Dates
using FilePathsBase
using FilePathsBase: /
using Tar

include("check_setups.jl")
include("setuplogs.jl")


const IMGPATH = tempname()*".png"
const SZ = 640 # width and height of the images
const FPS = 5 # frames per second
const CAM_PROCESS = Ref(run(`echo`))
const SETUPLOG = SetupLog()
const DATADIR = home() / "mnt" / "data"
mkpath(DATADIR)
const nicolas = Base.Libc.gethostname() == "nicolas"
const bucket = nicolas ? "nicolas-cage-skyroom" : "top-floor-skyroom2"


function readpngdata(io)
    blk = 65536;
    a = Array{UInt8}(undef, blk)
    readbytes!(io, a, 8)
    if view(a, 1:8) != magic(format"PNG")
        error("Bad magic.")
    end
    n = 8
    while !eof(io)
        if length(a)<n+12
            resize!(a, length(a)+blk)
        end
        readbytes!(io, view(a, n+1:n+12), 12)
        m = 0
        for i=1:4
            m = m<<8 + a[n+i]
        end
        chunktype = view(a, n+5:n+8)
        n=n+12
        if chunktype == codeunits("IEND")
            break
        end
        if length(a)<n+m
            resize!(a, max(length(a)+blk, n+m+12))
        end
        readbytes!(io, view(a, n+1:n+m), m)
        n = n+m
    end
    resize!(a,n)
    return a
end

const IMG = Ref{Vector{UInt8}}()

_start_camera(::Nothing) = ffmpeg() do exe
    # run(`$exe -y -hide_banner -loglevel error -f v4l2 -r $FPS -i /dev/video0 -vf "crop=in_h:in_h,scale=$(SZ)x$SZ" -update 1 $IMGPATH`, wait = false)
    io = open(`$exe -hide_banner -loglevel error -f v4l2 -r $FPS -s $(SZ)x$SZ -i /dev/video0 -c:v png -vf "crop=in_h:in_h,scale=$(SZ)x$SZ" -f image2pipe -`)
    @async while process_running(io)
        IMG[] = readpngdata(io)
    end
    return io
end

_start_camera(file) = ffmpeg() do exe
    # run(`$exe -y -hide_banner -loglevel error -f v4l2 -i /dev/video0 -filter_complex '[0:v]crop=in_h:in_h,split=2[out1][out2]' -map '[out1]' $file -map '[out2]' -s $(SZ)x$SZ -r $FPS -update 1 $IMGPATH`, wait = false)
    io = open(`$exe -hide_banner -loglevel error -f v4l2 -s 1920x1080 -i /dev/video0 -filter_complex '[0:v]crop=in_h:in_h,split=2[out1][out2]' -map '[out1]' $file -map '[out2]' -s $(SZ)x$SZ -r $FPS  -vcodec png -f image2pipe -`)
    @async while process_running(io)
        IMG[] = readpngdata(io)
    end
    return io
end

killcam() = while !process_exited(CAM_PROCESS[])
    kill(CAM_PROCESS[])
    sleep(0.1)
end

function start_camera(x)
    killcam()
    CAM_PROCESS[] = _start_camera(x)
end

Base.@kwdef mutable struct SkyRoom <: ReactiveModel
    kill::R{Bool} = false
    buttons::R{String} = quasar(:btn__group, "")
    recording::R{Bool} = false
    timestamp::String = strnow()
    beetleid::R{String} = ""
    comment::R{String} = ""
    save::R{Bool} = false
    backup::R{Bool} = false
end

flipon(f::Function, r::R{Bool}) = on(r) do tf
    if tf
        f()
        r[] = false
    end
end

function kill()
    killcam()
    # kill the LEDs and fans 
end



function record()
    model.timestamp = strnow()
    turnon!(SETUPLOG)
    folder = DATADIR / model.timestamp
    mkpath(folder)
    start_camera(folder / "video.h264")
    # record(allwind, folder)
end

function play()
    turnoff!(SETUPLOG)
    start_camera(nothing)
end

function save()
    model.recording[] = false
    folder = DATADIR / model.timestamp
    isdir(folder) || return nothing
    # if !isdir(folder)
    #     msg[] = "You haven't recorded a video yet, there is nothing to save"
    #     return nothing
    # end
    # msg[] = "Saving"
    md = Dict("recording_time" => model.timestamp, "beetle_id" => model.beetleid[], "comment" => model.comment[], "setuplog" => SETUPLOG.log)
    open(folder / "metadata.toml", "w") do io
        TOML.print(io, md)
    end
    model.comment[] = ""
    model.beetleid[] = ""
    model.timestamp = "garbage"
    # msg[] = "Saved"
end

backup() = for folder in readpath(DATADIR)
    tmp = Tar.create(string(folder))
    rm(folder, recursive = true)
    name = basename(folder)
    run(`aws s3 mv $tmp s3://$bucket/$name.tar --quiet`)
end

function restart()
    global model

    start_camera(nothing)
    model = Stipple.init(SkyRoom(), debounce=1)

    on(model.recording) do recording
        recording ? record() : play()
    end

    flipon(kill, model.kill)
    flipon(save, model.save)
    flipon(backup, model.backup)

end

function ui()
    m = dashboard(vm(model), [
                              script(
                                     """
                                     setInterval(function() {
                                     var img = document.getElementById("frame");
                                     img.src = "frame/" + new Date().getTime();
                                     }, $(1000 ÷ FPS));
                                     """
                                    ),        
                              heading("SkyRoom"),
                              row(cell(class="st-module", [
                                                           """
                                                           <img id="frame" src="frame" style="height: $(SZ)px; max-width: $(SZ)px" />
                                                           """
                                                          ])),
                              row(cell(class="st-module", [
                                                           p(button("Kill", @click("kill = true"))),
                                                           p(quasar(:uploader, multiple = false, accept = ".toml", auto__upload = true, hide__upload__btn = true, label = "Upload Setup file", url = "/upload")),
                                                           p(button("notify", @click("showNotif()")))
                                                          ])),
                              row(cell(class="st-module", [
                                                           p(toggle("Recording", fieldname = :recording)),
                                                           p(["Beetle ID", input("", placeholder="Type in the ID of the beetle", @bind(:beetleid))]),
                                                           p(["Comment", input("", placeholder="Type in any comments", @bind(:comment))]),
                                                           p(button("Save", @click("save = true"))),
                                                           p(button("Backup", @click("backup = true"))),
                                                          ]))
                             ], title = "SkyRoom")

    return html(m)
end

js_methods(m::Any) = """
     showNotif () {
       this.$q.notify({
         message: 'Jim pinged you.',
         color: 'purple'
       })
     }
"""

route("/", ui)

route("frame/:timestamp") do 
    # HTTP.Messages.Response(200, read(IMGPATH))
    HTTP.Messages.Response(200, IMG[])
end

route("/upload", method = POST) do
    files = Genie.Requests.filespayload() # type: Dict{String, Genie.Input.HttpFile}
    isempty(files) && @info "No file uploaded"
    p = only(values(files))
    d = checksetups(String(p.data))
    if d isa String

        @warn d
    else
        model.buttons[] = quasar(:btn__group, button.(keys(d)))
    end
end

Genie.config.server_host = "127.0.0.1"

restart()

up(open_browser = true)


