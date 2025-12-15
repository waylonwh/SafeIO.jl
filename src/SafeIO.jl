"""
    SafeIO

A Julia package for safe file I/O operations that protects against accidental data loss by
automatically backing up existing files and variables before overwriting.

For more details, see https://github.com/waylonwh/SafeIO.jl.
"""
module SafeIO

include("utils.jl")
include("save.jl")
include("load.jl")

using .Utils, .Save, .Load

# Save
export protect
export Protected, @protect
export save_object
# Load
export safe_assign!, @safe_assign
export safehouse, house!, retrieve
export load_object!

end # module SafeIO
