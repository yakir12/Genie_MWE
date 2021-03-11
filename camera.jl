struct Camera
    process::Ref{Base.Process}
    path::String
    sz::Int
    fps::Int
end

const CAM = Camera(Ref(run(`echo`)), tempname()*".png", 640, 5)

Base.kill() = while !process_exited(CAM.process[])
    kill(CAM.process[])
    sleep(0.1)
end

function play()
    kill()
    ffmpeg() do exe
        CAM.process[] = run(`$exe -y -hide_banner -loglevel error -f v4l2 -r $(CAM.fps) -i /dev/video0 -vf "crop=in_h:in_h,scale=$(CAM.sz)x$(CAM.sz)" -update 1 $(CAM.path)`, wait = false)
    end
end

function record(file)
    kill()
    ffmpeg() do exe
        CAM.process[] = run(`$exe -y -hide_banner -loglevel error -f v4l2 -i /dev/video0 -filter_complex '[0:v]crop=in_h:in_h,split=2[out1][out2]' -map '[out1]' $file -map '[out2]' -s $(CAM.sz)x$(CAM.sz) -r $(CAM.fps) -update 1 $(CAM.path)`, wait = false)
    end
end

snap() = HTTP.Messages.Response(200, read(CAM.path))








# # function readpngdata(io)
# #     blk = 65536;
# #     a = Array{UInt8}(undef, blk)
# #     readbytes!(io, a, 8)
# #     if view(a, 1:8) != magic(format"PNG")
# #         error("Bad magic.")
# #     end
# #     n = 8
# #     while !eof(io)
# #         if length(a)<n+12
# #             resize!(a, length(a)+blk)
# #         end
# #         readbytes!(io, view(a, n+1:n+12), 12)
# #         m = 0
# #         for i=1:4
# #             m = m<<8 + a[n+i]
# #         end
# #         chunktype = view(a, n+5:n+8)
# #         n=n+12
# #         if chunktype == codeunits("IEND")
# #             break
# #         end
# #         if length(a)<n+m
# #             resize!(a, max(length(a)+blk, n+m+12))
# #         end
# #         readbytes!(io, view(a, n+1:n+m), m)
# #         n = n+m
# #     end
# #     resize!(a,n)
# #     return a
# # end
#
#
# _start_camera(::Nothing) = ffmpeg() do exe
#     run(`$exe -y -hide_banner -loglevel error -f v4l2 -r $FPS -i /dev/video0 -vf "crop=in_h:in_h,scale=$(SZ)x$SZ" -update 1 $IMGPATH`, wait = false)
#     # io = open(`$exe -hide_banner -loglevel error -f v4l2 -r $FPS -s $(SZ)x$SZ -i /dev/video0 -c:v png -vf "crop=in_h:in_h,scale=$(SZ)x$SZ" -f image2pipe -`)
#     # @async while process_running(io)
#         # IMG[] = readpngdata(io)
#     # end
#     # return io
# end
#
# _start_camera(file) = ffmpeg() do exe
#     run(`$exe -y -hide_banner -loglevel error -f v4l2 -i /dev/video0 -filter_complex '[0:v]crop=in_h:in_h,split=2[out1][out2]' -map '[out1]' $file -map '[out2]' -s $(SZ)x$SZ -r $FPS -update 1 $IMGPATH`, wait = false)
#     # io = open(`$exe -hide_banner -loglevel error -f v4l2 -s 1920x1080 -i /dev/video0 -filter_complex '[0:v]crop=in_h:in_h,split=2[out1][out2]' -map '[out1]' $file -map '[out2]' -s $(SZ)x$SZ -r $FPS  -vcodec png -f image2pipe -`)
#     # @async while process_running(io)
#         # IMG[] = readpngdata(io)
#     # end
#     # return io
# end
#
# killcam() = while !process_exited(CAM_PROCESS[])
#     kill(CAM_PROCESS[])
#     sleep(0.1)
# end
#
# function start_camera(x)
#     killcam()
#     CAM_PROCESS[] = _start_camera(x)
# end
#
# # getframe() = HTTP.Messages.Response(200, IMG[])
#
# getframe() = HTTP.Messages.Response(200, read(IMGPATH))
#
