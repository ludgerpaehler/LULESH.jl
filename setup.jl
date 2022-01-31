#!/bin/env julia
import Pkg
Pkg.activate(".")


Enzyme_path = Base.find_package("Enzyme")
if Enzyme_path === nothing
    error("First instantiate Project")
end
dir = joinpath(dirname(dirname(Enzyme_path)), "deps")

@info "Building Enzyme from master"

run(`$(Base.julia_cmd()) --project=$(dir) -e 'import Pkg; Pkg.instantiate()'`)
run(`$(Base.julia_cmd()) --project=$(dir) $(dir)/build_local.jl`)

import MPI
MPI.install_mpiexecjl(;destdir=".", force=true)
