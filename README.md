# SafeIO.jl

[![CI](https://github.com/waylonwh/SafeIO.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/waylonwh/SafeIO.jl/actions/workflows/CI.yml)

A Julia package for safe file I/O operations that protects against accidental data loss by automatically backing up existing files and variables before overwriting.

## Features

- **Protected File Saving**: Automatically backs up existing files before saving new content
- **Safe Variable Assignment**: Stores previous variable values in a "safehouse" before reassignment
- **JLD2 Integration**: Convenient functions for saving/loading Julia objects with protection
- **Unique Identifiers**: Uses timestamped unique IDs for backup files and stored values
- **Error Recovery**: Preserves backups even when save operations fail

## Installation

```julia
using Pkg
Pkg.add("SafeIO")
```

Or in the Julia REPL package mode:
```julia
pkg> add SafeIO
```

## Quick Start

```julia
using SafeIO
```

### Protected File Saving

Use `@protect` or `protect` to protect files from being accidentally overwritten:

```julia
# First save - creates the file
@protect write(Protected("./greeting.txt"), "Hello World")

# Second save - backs up existing file with unique ID before saving
@protect write(Protected("./greeting.txt"), "Hello Again!")
# ┌ Warning: File ./greeting.txt already exists. Last modified on 13 Dec 2025 at 00:40:00.
# │ The EXISTING file has been renamed to ./greeting_1689874a.txt.
# └ @ SafeIO.Save src/save.jl:70

# Use function `protect` to perform complex operations while protecting the file
protect("./greeting.txt") do path
    io = open(path, "w")
    write(io, "Hello Once More!")
    write(io, "\nHave a great day!")
    close(io)
end
# ┌ Warning: File ./greeting.txt already exists. Last modified on 15 Dec 2025 at 18:00:25.
# │ The EXISTING file has been renamed to ./greeting_726ae51e.txt.
# └ @ SafeIO.Save src/save.jl:82
```

### Safe Object Storage with JLD2

```julia
# Save Julia objects safely
save_object("Hello World", "./greeting.jld2")

# Saving again backs up the existing file
save_object("Hello Again!", "./greeting.jld2")
# ┌ Warning: File ./greeting.jld2 already exists. Last modified on 13 Dec 2025 at 00:48:04.
# │ The EXISTING file has been renamed to ./greeting_38ff9f7a.jld2.
# └ @ SafeIO.Save src/save.jl:70

# Load objects safely into variables
load_object!(:greeting, "./greeting.jld2")
```

### Safe Variable Assignment

```julia
# First assignment
@safe_assign x = 1

# Reassigning stores the old value in a safehouse
@safe_assign x = 2
# ┌ Warning: Variable `x` already defined in Main. The existing value has been stored
# │ in safehouse `Main.SAFEHOUSE` with ID 0x6b36583a.
# └ @ SafeIO.Load src/load.jl:267

# View stored values
SAFEHOUSE
# SafeIO.Load.Safehouse{Main} with 1 refugees in 1 variables:
#   SafeIO.Load.Refugee{Main}(x#6b36583a = 1)

# Retrieve old values
old_values = SAFEHOUSE[:x]
only(old_values)[]  # Access the stored value: 1
```

## API Reference

### Save Module

#### `protect(iofunc::Function, path::AbstractString)`

Protect a file at `path` when performing an operation. If the file exists and is modified during the save, the original is backed up with a unique identifier.

```julia
protect("./data.txt") do path
    write(path, "content")
end
```

#### `@protect function_call(..., Protected("path"), ...)`

Macro that wraps any function call to protect the file specified by `Protected`.

```julia
@protect write(Protected("./data.txt"), "content")
@protect CSV.write(Protected("./data.csv"), df)
```

#### `save_object(obj, path::AbstractString)`

Save a Julia object to a JLD2 file with automatic backup of existing files.

```julia
save_object(my_data, "./data.jld2")
```

### Load Module

#### `safe_assign!(to::Symbol, val, modu::Module=Main; house=:SAFEHOUSE, constant=false)`

Safely assign a value to a variable, storing any existing value in the safehouse first.

```julia
safe_assign!(:x, 42)
safe_assign!(:x, 100)  # Previous value (42) stored in SAFEHOUSE
```

#### `@safe_assign [const] [global] var = value` / `@safe_assign ([const] [global] var = value; :SAFEHOUSE)`

Macro for safe assignment expressions.

```julia
@safe_assign x = 1
@safe_assign (x = 2; :SAFEHOUSE)
@safe_assign const y = 3
```

#### `load_object!(to::Symbol, path::AbstractString, modu::Module=Main)`

Load an object from a JLD2 file and safely assign it to a variable.

```julia
load_object!(:data, "./data.jld2")
```

#### `safehouse(modu::Module=Main, name::Symbol=:SAFEHOUSE)`

Create or retrieve a safehouse for storing variable backups.

```julia
house = safehouse()  # Get or create SAFEHOUSE in Main module
```

#### `house!(var::Symbol, safehouse::Safehouse)`

Manually store the current value of a variable in the safehouse.

```julia
x = 10
house!(:x, safehouse())  # Store current value of x
```

#### `retrieve(id::UInt32, safehouse)` / `retrieve(var::Symbol, safehouse)`

Retrieve stored values from the safehouse by ID or variable name.

`Safehouse[::UInt32]` and `Safehouse[::Symbol]` can also be used.

```julia
# Get all stored values of variable x
old_values = retrieve(:x, SAFEHOUSE)
old_values = SAFEHOUSE[:x]

# Get a specific stored value by ID
value = retrieve(0xf13f7776, SAFEHOUSE)
value = SAFEHOUSE[0xf13f7776]
value[]  # Access the actual value
```

## Dependencies

- [JLD2.jl](https://github.com/JuliaIO/JLD2.jl) - Julia object serialization
- [TimeZones.jl](https://github.com/JuliaTime/TimeZones.jl) - Timezone-aware timestamps
- CRC32c - File change detection
- Dates, UUIDs - Standard library

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Waylon Wu (<waylon_wu@outlook.com>)
