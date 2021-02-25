using Stipple, StippleUI, FFMPEG_jll
using Genie.Renderer.Html

const IMGPATH = "img/demo.png"

const SZ = 240 # width and height of the images
const FPS = 10 # frames per second
ffmpeg() do exe # record from camera a frame, rewriting to `IMGPATH` 10 (= `FPS`) times a second
    run(`$exe -y -hide_banner -loglevel error -f v4l2 -video_size $(SZ)x$SZ -i /dev/video0 -r $FPS -update 1 public/$IMGPATH`, wait = false)
end

Base.@kwdef mutable struct Dashboard1 <: ReactiveModel # all this stuff with the model, is not really used here. I just keep it for the call to dashboard below
end

function restart()
    global model

    model = Stipple.init(Dashboard1(), debounce=1)
end

function ui()
    dashboard(vm(model), [
        script(
               """
                       setInterval(function() {
                       var img = document.getElementById("frame");
                       img.src = "$IMGPATH#" + new Date().getTime();
                       }, 500);
               """
              ),
        heading("Image Demo"),
        row(cell(class="st-module", [
            quasar(:img, id = "frame", src = IMGPATH, style="height: 140px; max-width: 140px")
        ]))
    ], title = "Image Demo") |> html
end

route("/", ui)

Genie.config.server_host = "127.0.0.1"

restart()

up(open_browser = true)
