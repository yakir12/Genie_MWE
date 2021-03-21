file = "/home/pi/mnt/data/tmp.mp4"
sz = 640
fps = 5
IMG_FILE = "/home/pi/mnt/data/frame.png"
p = ffmpeg() do exe 
    run(`$exe -y -hide_banner -loglevel error -f v4l2 -i /dev/video0 -filter_complex '[0:v]crop=in_h:in_h,fps=30,split=2[out1][out2]' -map '[out1]' $file -map '[out2]' -s $(sz)x$sz -r $fps -update 1 $IMG_FILE`, wait = false)
end

cam = VideoIO.opencamera()
img = read(cam)

encoder_options = (crf=0, preset="ultrafast")
framerate=3
open_video_out("/home/pi/mnt/data/tmp.mp4", img, framerate=framerate, encoder_options=encoder_options) do writer
    for i in 1:5framerate
        read!(cam, img)
        write(writer, img)
    end
end



