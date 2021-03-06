"""
    h5dump(filename)

Dumps the group/data tree of a HDF5 file.
"""
h5dump(f::HDF5.HDF5File, space::String="      ") = h5dump_recursive(f["/"], space)

function h5dump(filename::String, space::String="      ")
  HDF5.h5open(filename, "r+") do f
    h5dump(f,space)
  end
end
function h5dump_recursive(g::HDF5.HDF5Group, space::String, level::Int=0)
    println(space ^ level, HDF5.name(g))
    for el in HDF5.names(g)
        if typeof(g[el]) == HDF5.HDF5Group
            h5dump_recursive(g[el], space, level+1)
        else
          println(space ^ (level+1), el)
        end
   end
end
export h5dump

"""
    jlddump(filename)

Dumps the group/data tree of a JLD file.
"""
jlddump(f::JLD.JldFile, space::String="      ") = h5dump(f.plain, space)
function jlddump(filename::String, space::String="      ")
  JLD.jldopen(filename, "r+") do f
    jlddump(f,space)
  end
end
export jlddump

"""
    h5delete(filename, element)

Deletes a group or dataset from a HDF5 file. However, due to the HDF5 standard
it might be that space is not freed.
"""
function h5delete(filename::String, el::String)
  HDF5.h5open(filename, "r+") do f
    if !HDF5.exists(f, el)
        error("Element \"$el\" does not exist in \"$filename\".")
    end
    HDF5.o_delete(f, el)
  end
  nothing
end
export h5delete

"""
    h5repack(src, trg)

Repacks a HDF5 file e.g. to free unused space. If `src == trg`Wrapper to external h5repack
application.
"""
function h5repack(src::String, trg::String)
    if src == trg   h5repack(src)  end
    @static if Sys.iswindows()
        read(`h5repack.exe $src $trg`, String)
    end
    @static if Sys.islinux()
        read(`h5repack $src $trg`, String)
    end
end
function h5repack(filename::String)
    h5repack(filename, "tmp.h5")
    mv("tmp.h5",filename,force=true)
end
export h5repack


"""
  saverng(filename [, rng::MersenneTwister; group="GLOBAL_RNG"])
  saverng(HDF5.HDF5File [, rng::MersenneTwister; group="GLOBAL_RNG"])

Saves the current state of Julia's random generator (`Random.GLOBAL_RNG`) to HDF5.
"""
function saverng(f::HDF5.HDF5File, rng::MersenneTwister=Random.GLOBAL_RNG; group::String="GLOBAL_RNG")
  g = endswith(group, "/") ? group : group * "/"
  try
    if HDF5.exists(f, g)
      HDF5.o_delete(f, g)
    end

    f[g*"idxF"] = rng.idxF
    f[g*"idxI"] = rng.idxI
    f[g*"state_val"] = rng.state.val
    f[g*"vals"] = rng.vals
    f[g*"seed"] = rng.seed
    f[g*"ints"] = Int.(rng.ints)
  catch e
    error("Error while saving RNG state: ", e)
  end
  nothing
end
function saverng(filename::String, rng::MersenneTwister=Random.GLOBAL_RNG; group::String="GLOBAL_RNG")
  mode = isfile(filename) ? "r+" : "w"
  HDF5.h5open(filename, mode) do f
    saverng(f, rng; group=group)
  end
end
export saverng

"""
  loadrng(filename [; group="GLOBAL_RNG"]) -> MersenneTwister
  loadrng(f::HDF5.HDF5File [; group="GLOBAL_RNG"]) -> MersenneTwister

Loads a random generator from HDF5.
"""
function loadrng(f::HDF5.HDF5File; group::String="GLOBAL_RNG")::MersenneTwister
  rng = MersenneTwister(0)
  g = endswith(group, "/") ? group : group * "/"
  try
    rng.idxI = read(f[g*"idxI"])
    rng.idxF = read(f[g*"idxF"])
    rng.state = Random.DSFMT.DSFMT_state(read(f[g*"state_val"]))
    rng.vals = read(f[g*"vals"])
    rng.seed = read(f[g*"seed"])
    rng.ints = UInt128.(read(f[g*"ints"]))
  catch e
    error("Error while restoring RNG state: ", e)
  end
  return rng
end
function loadrng(filename::String; group::String="GLOBAL_RNG")
  HDF5.h5open(filename, "r") do f
    loadrng(f; group=group)
  end
end
export loadrng

"""
  restorerng(filename [; group="GLOBAL_RNG"]) -> Void
  restorerng(f::HDF5.HDF5File [; group="GLOBAL_RNG"]) -> Void

Restores a state of Julia's random generator (`Random.GLOBAL_RNG`) from HDF5.
"""
function restorerng(filename::String; group::String="GLOBAL_RNG")
  HDF5.h5open(filename, "r") do f
    restorerng(f; group=group)
  end
  nothing
end
restorerng(f::HDF5.HDF5File; group::String="GLOBAL_RNG") = setrng(loadrng(f; group=group))
export restorerng

"""
  jldwrite(filename::AbstractString, name::AbstractString, obj; compress::Bool=false)

"""
function jldwrite(filename::AbstractString, name::AbstractString, obj; compress::Bool=false)
  mode = isfile(filename) ? "r+" : "w"
  jldopen(filename, mode, compress=compress) do f
    write(f, name, obj)
  end
  nothing
end
export jldwrite

"""
  jldread(filename::AbstractString, name::AbstractString)
  
"""
function jldread(filename::AbstractString, name::AbstractString)
  jldopen(filename) do f
    return read(f[name])
  end
end
export jldread


"""
  has(filename::AbstractString, name::AbstractString)

Checks wether a JLD/HDF5 file has a dataset with name `name`.
"""
function has(filename::AbstractString, name::AbstractString)
  h5open(filename) do f
    return HDF5.has(f.plain, name)
  end
end
