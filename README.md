# Genie_MWE

## Requirements
1. For this specific example you'll need a webcam connected to the computer you are running this on.
2. Julia installed (I have 1.6.0-beta1, but it shouldn't matter too much: there's a rc1 now, I think)

## How to run
1. Clone this
2. `cd` into here
3. start Julia using the included `Project.toml` file with:
   ```
   $ julia --project=.
   ```
4. Include the `mwe.jl` file:
   ```julia
   julia> include("mwe.jl")
   ```
5. A webpage is automatically opened with a picture of your face
6. Your face is sad but you can't see that becuase it's not updating (despite the fact that `public/img/demo.img` is indeed updating)
