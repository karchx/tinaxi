// +-------------------+
// |  Transport (TCP)  |  ← sockets, epoll, threads
// +-------------------+
//
// This module provides TCP transport functionality using sockets, epoll, and threads.

const std = @import("std");
const kv = @import("kv.zig");
const command = @import("command.zig");
const Allocator = std.mem.Allocator;
const net = std.net;
const posix = std.posix;

pub fn initServer(_: Allocator) !void {
    std.debug.print("Starting TCP server...\n", .{});
    const address = try std.net.Address.parseIp4("127.0.0.1", 9999);

    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;
    const listener = try posix.socket(address.any.family, tpe, protocol);

    defer posix.close(listener);

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &address.any, address.getOsSockLen());
    try posix.listen(listener, 128);

    // var store = kv.Kv.init(allocator);
    // defer store.deinit();

    while (true) {
        const client_address: net.Address = undefined;
        //const client_address_len: posix.socklen_t = @sizeOf(net.Address);

        // const socket = posix.accept(listener, &client_address.any, &client_address_len, 0) catch |err| {
        //     std.debug.print("Accept failed: {any}\n", .{err});
        //     continue;
        // };

        std.debug.print("connected {f}\n", .{client_address});

        // const thread = try std.Thread.spawn(.{}, handlerClient, .{ socket, &store, allocator });

        // thread.detach();
    }
}

fn handlerClient(socket: posix.socket_t, store: *kv.Kv, allocator: Allocator) !void {
    defer posix.close(socket);

    var message_buffer: std.ArrayList(u8) = .empty;
    defer message_buffer.deinit(allocator);

    var buf: [128]u8 = undefined;

    while (true) {
        const read = try posix.read(socket, &buf);
        std.debug.print("Received {d} bytes\n", .{read});

        if (read == 0) {
            std.debug.print("Connection closed by peer\n", .{});
            break;
        }

        try message_buffer.appendSlice(allocator, buf[0..read]);

        // check for complete lines
        // using '\n' as line delimiter
        // TODO: add Length-prefixed messages support
        if (std.mem.indexOfScalar(u8, message_buffer.items, '\n')) |_| {
            write(socket, message_buffer.items, store) catch |err| {
                std.debug.print("Write failed: {any}\n", .{err});
            };
            message_buffer.clearRetainingCapacity();
        }
    }
}

fn write(socket: posix.socket_t, msg: []const u8, store: *kv.Kv) !void {
    const cmd = try command.parseCommand(msg);
    switch (cmd) {
        .Set => |set_cmd| {
            std.debug.print("SET {s} {s}\n", .{ set_cmd.key, set_cmd.value });
            try store.set(set_cmd.key, set_cmd.value);
            const resp = command.Response{ .Ok = {} };
            try command.writeCommand(posix.write, socket, resp);
        },
        .Get => |get_cmd| {
            const value = store.get(get_cmd.key) orelse null;
            if (value) |v| {
                const resp = command.Response{ .Value = v };
                try command.writeCommand(posix.write, socket, resp);
            } else {
                const resp = command.Response{ .NotFound = {} };
                try command.writeCommand(posix.write, socket, resp);
            }
        },
        .Del => |del_cmd| {
            const existed = store.del(del_cmd.key);
            if (existed) {
                const resp = command.Response{ .Ok = {} };
                try command.writeCommand(posix.write, socket, resp);
            } else {
                const resp = command.Response{ .NotFound = {} };
                try command.writeCommand(posix.write, socket, resp);
            }
        },
    }
}
