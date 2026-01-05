const std = @import("std");
const transport = @import("transport.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 1 and std.mem.eql(u8, args[1], "connect")) {
        try repl();
    } else {
        try transport.initServer(allocator);
    }

}

pub fn repl() !void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;

    var stdin_buf: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);
    const stdin = &stdin_reader.interface;

    try print("> ", stdout);

    while (stdin.takeDelimiterExclusive('\n')) | line| {
        try print(line, stdout);
    } else |err| {
        return err;
    }
}

fn print(msg: []const u8, writer: *std.Io.Writer) !void {
    try writer.print("{s}", .{ msg });
    try writer.flush();
}
