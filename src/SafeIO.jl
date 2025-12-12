module SafeIO

include("utils.jl")
include("save.jl")
include("load.jl")

using .Utils, .Save, .Load

# Save
export ProtectedPath
export @safe_save
export protect, save_object
# Load
export safe_assign!, @safe_assign
export safehouse, house!, retrieve
export load_object!

end # module SafeIO
