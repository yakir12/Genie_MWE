using Stipple, StippleUI
using Genie.Renderer.Html
using HTTP
using FFMPEG_jll

const IMGPATH = "img/demo.png"

const SZ = 640 # width and height of the images
const FPS = 5 # frames per second

start_camera() = ffmpeg() do exe
    run(`$exe -y -hide_banner -loglevel error -f v4l2 -r $FPS -i /dev/video0 -vf "crop=in_h:in_h,scale=$(SZ)x$SZ" -update 1 public/$IMGPATH`, wait = false)
end

start_camera(file) = ffmpeg() do exe
    run(`$exe -y -hide_banner -loglevel error -f v4l2 -i /dev/video0 -filter_complex '[0:v]crop=in_h:in_h,split=2[out1][out2]' -map '[out1]' $file -map '[out2]' -s $(SZ)x$SZ -r $FPS -update 1 public/$IMGPATH`, wait = false)
end



const CAM_PROCESS = Ref(start_camera())
Base.@kwdef mutable struct SkyRoom <: ReactiveModel
    recording::R{Bool} = false
    beetleid::R{String} = ""
    comment::R{String} = ""
end

function restart()
    global model

    model = Stipple.init(SkyRoom(), debounce=1)

    on(model.recording) do recording
        kill(CAM_PROCESS[])
        sleep(1)
        CAM_PROCESS[] = recording ? start_camera("a.mkv") : start_camera()
    end
end

function ui()
    dashboard(vm(model), [
                          script(
                                 """
                                 setInterval(function() {
                                 var img = document.getElementById("frame");
                                 img.src = "$IMGPATH#" + new Date().getTime();
                                 }, $(round(Int, 1000/FPS)));
                                 """
                                ),        
                          heading("SkyRoom"),
                          row(cell(class="st-module", [
                                                       """
                                                       <img id="frame" src="$IMGPATH" style="height: $(SZ)px; max-width: $(SZ)px" />
                                                       """
                                                      ])),
                          row(cell(class="st-module", [
                                                       p(toggle("Recording", fieldname = :recording)),
                                                       p(["Beetle ID", input("", placeholder="Type in the ID of the beetle", @bind(:beetleid))]),
                                                       p(["Comment", input("", placeholder="Type in any comments", @bind(:comment))])
                                                      ]))
                         ], title = "SkyRoom") |> html
end

route("/", ui)

Genie.config.server_host = "127.0.0.1"

restart()

up(open_browser = true)
