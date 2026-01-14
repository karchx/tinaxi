const std = @import("std");
const Transport = @import("transport.zig");
const Store = @import("store.zig");
const command = @import("command.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 1 and std.mem.eql(u8, args[1], "connect")) {
        var storedb = try Store.Store.init(allocator);
        defer storedb.deinit();

        try repl(storedb, allocator);
    } else {
        try Transport.initServer(allocator);
    }

}

pub fn repl(store: *Store.Store, alloc:  std.mem.Allocator) !void {
    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);

    std.debug.print("Starting REPL (type 'exit' to quit)\n", .{});
    var line = std.Io.Writer.Allocating.init(alloc);
    defer line.deinit();

    while (true) {
        std.debug.print("> ", .{});

        _ = stdin_reader.interface.streamDelimiter(&line.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };

        _ = stdin_reader.interface.toss(1);
        try write(line.written(), store);
        line.clearRetainingCapacity();
    }

    // while(true) {
    //     try print("> ", stdout);

    //     const line = stdin.takeDelimiterExclusive('\n') catch |err| {
    //         if (err == error.EndOfStream) return;
    //         return err;
    //     };
    //     try print(line, stdout);
    // }
}

fn print(msg: []const u8, writer: *std.Io.Writer) !void {
    try writer.print("{s}", .{ msg });
    try writer.flush();
}

fn write(msg: []const u8, store: *Store.Store) !void {
    const cmd = command.parseCommand(msg) catch |err| {
        std.log.warn("Failed to parse command: {any}", .{err});
        return;
    };
    switch (cmd) {
        .Set => |set_cmd| {
            try store.put(set_cmd.key, set_cmd.value);
            // const resp = command.Response{ .Ok = {} };
            // try command.writeCommand(posix.write, socket, resp);
        },
        .Get => |get_cmd| {
            const value = try store.get(get_cmd.key) orelse null;
            if (value) |v| {
                std.debug.print("GET {s}\n", .{ v });
                // const resp = command.Response{ .Value = v };
                // try command.writeCommand(posix.write, socket, resp);
            } else {
                // const resp = command.Response{ .NotFound = {} };
                // try command.writeCommand(posix.write, socket, resp);
            }
        },
        .Del => |del_cmd| {
            std.debug.print("DEL {s}\n", .{ del_cmd.key });
            //const existed = store.del(del_cmd.key);
            //if (existed) {
            //    const resp = command.Response{ .Ok = {} };
            //    try command.writeCommand(posix.write, socket, resp);
            //} else {
            //    const resp = command.Response{ .NotFound = {} };
            //    try command.writeCommand(posix.write, socket, resp);
            //}
        },
    }
}
