module Utils # SafeIO.

import UUIDs

export unique_id, reprhex, iobuffer

unique_id()::UInt32 = UInt32(UUIDs.uuid1().value >> 96)

(reprhex(hex::T, prefix::Bool=false)::String) where T<:Unsigned = repr(hex)[(prefix ? 1 : 3):end]

iobuffer(io::IO; sizemodifier::NTuple{2,Int}=(0, 0))::IOContext = IOContext(
    IOBuffer(),
    :limit => true,
    :displaysize => displaysize(io) .+ sizemodifier,
    :compact => true,
    :color => true
)

end # module Utils
