using Stipple, StippleUI
using Genie.Renderer.Html
using HTTP

const IMGPATH = "img/demo.png"

const SZ = 240 # width and height of the images
const FPS = 10 # frames per second

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
                       img.src = "frame/" + new Date().getTime();
                       }, 1000);
               """
              ),        
        heading("Image Demo"),
        row(cell(class="st-module", [
            """
                <img id="frame" src="frame" style="height: 140px; max-width: 140px" />
            """
            # the quasar thing doesn't actually create an img tag
            # instead, it uses a div with a background image
            # and it makes up its own ids, so you lose the "frame" id
            # which is why the vanilla js doesn't work
            # quasar(:img, id = "frame", src = "frame", style="height: 140px; max-width: 140px")
        ]))
    ], title = "Image Demo") |> html
end

function getframe()
    # here's where you'd put your code to grab the image from the camera
    # you'd then return an HTTP.Response object to stream the image back to the browser
    # https://github.com/JuliaWeb/HTTP.jl
    # this way, you never have to write anything to the disk
    # that'll have the benefit of speeding things up (I/O is slow)
    # and you won't have to clean up all of those frames from wherever they're being written
    return HTTP.request("GET", "https://cataas.com/cat") 
end

route("/", ui)

# this is our new route which returns the image
route("/frame/:timestamp", getframe)

Genie.config.server_host = "127.0.0.1"

restart()

up(open_browser = true)
