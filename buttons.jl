function killall()
    kill()
    # kill the LEDs and fans 
end

function toggle_record(recording) 
    if recording
        model.disable_save[] = false
        model.timestamp[] = now()
        turnon!()
        mkpath(model.folder[])
        record(model.folder[] / "video.h264")
        # record(allwind, model.folder[])
    else
        play()
    end
end

function save()
    model.recording[] = false
    # if !isdir(model.folder[])
    #     model.msg[] = "You haven't recorded a video yet, there is nothing to save"
    #     return nothing
    # end
    md = Dict("title" => model.title[], "experimenters" => model.experimenters[], "recording_time" => model.timestamp[], "beetle_id" => model.beetleid[], "comment" => model.comment[], "setuplog" => getlog())
    open(model.folder[] / "metadata.toml", "w") do io
        TOML.print(io, md)
    end
    turnoff!()
    model.disable_save[] = true
    model.comment[] = ""
    model.beetleid[] = ""
    model.timestamp[] = now()
end

_n2backup() = count(isdir, readpath(DATADIR))

function backup() 
    n = _n2backup()
    model.backedup[] = 0.0
    for folder in readpath(DATADIR)
        tmp = Tar.create(string(folder))
        rm(folder, recursive = true)
        name = basename(folder)
        run(`aws s3 mv $tmp s3://$bucket/$name.tar --quiet`)
        model.backedup[] = 100 - 100_n2backup()/n
    end
    model.backedup[] = 100.0
end
