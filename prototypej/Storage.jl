module Storage

#
#  The object managing output storage for the system.
#
#  The object has two purposes: 
#
#    * gather data that arrives per-frame and package it into
#      readable output files, one per frame.
# 
#    * gather data that will be stored in a single file for all 
#      time points at the end of the simulation
#
#   Note: the data may overlap between storage types.
#
#


# the global storage manager object
global sm = nothing


type StorageManager
    output_dir :: String
    log_name :: String
    frame_prefix :: String
    
    tag_cfg :: Dict
    current_frame :: Dict
    frame_ndx :: Int
    flushed :: Bool

    ts_store :: Dict

    log_io

    StorageManager(out_dir, log_name, frame_prefix) = new(out_dir, log_name, frame_prefix, Dict{String,Any}(), Dict{String,Any}(), 1, true, Dict{String,Any}(), nothing)
end



function sopen(out_dir, log_name, frame_prefix)
    global sm
    sm = StorageManager(out_dir, log_name, frame_prefix)
    log_path = join([out_dir, log_name], "/")
    sm.log_io = open(log_path, "w")
    println(sm.log_io, "Initialized log at [$log_path]")
end


function sclose()
    global sm
    close(sm.log_io)
    sm = nothing
end


function setup_tag(tag :: String, series_store :: Bool, stdout :: Bool, logout :: Bool)
    sm.tag_cfg[tag] = (series_store, stdout, logout)
end


function next_frame()
    flush_frame()
    sm.current_frame = Dict{String,Any}()
    sm.flushed = false
end


function flush_frame()

    # if the frame is already flushed, don't call again
    if sm.flushed == false

        f = sm.current_frame
        kk = keys(f)

        # another construction to avoid "," after last item
        if length(kk) > 0

            # render the data in python mode
            ff_name = join([sm.output_dir, string(sm.frame_prefix, string(sm.frame_ndx))], "/")
            io = open(ff_name, "w")
            println(io, "{")

            python_render_item(io, kk[1], f[kk[1]])
            for k in kk[2:]
                println(io, ",")
                python_render_item(io, k, f[k])
            end
            println(io)
            println(io, "}")
            close(io)
        end
        
        sm.frame_ndx += 1

        # log end of frame to io
        println(sm.log_io, "end-of-frame [$ff_name]")
        
        # indicate this frame has been flushed
        sm.flushed = true
    end
end


function push(tag :: String, data)
    c = sm.tag_cfg[tag]
    sm.current_frame[tag] = data

    # store in time series store if requested
    if c[1]
        if has(sm.ts_store, tag)
            push!(sm.ts_store[tag], data)
        else
            sm.ts_store[tag] = [data]
        end
    end

    # if stdout requested print it
    if c[2]
        python_render_item(STDOUT, tag, data)
        println(STDOUT)
    end

    # if logout is requested
    if c[3] 
        python_render_item(sm.log_io, tag, data)
        println(sm.log_io)
    end
end


function python_render_item(io :: IO, k :: String, v :: Array{Any})
    show(io, k)
    print(io, " : [")

    # construct to avoid "," after last item in list
    if length(v) > 0
        show(io, v[1])
        for i in v[2:]
            print(io, ", ")
            show(io, i)
        end
    end
    print(io, "]")
end


function python_render_item(io :: IO, k :: String, v :: Any)
    show(io, k)
    print(io, " : ")
    show(io, v)
end


end