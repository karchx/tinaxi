const std = @import("std");
const transport = @import("transport.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    try transport.initServer(allocator);
}
