const transport = @import("transport.zig");

pub fn main() !void {
    try transport.initServer();
}
