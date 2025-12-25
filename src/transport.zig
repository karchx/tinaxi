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

pub fn initServer(allocator: Allocator) !void {
    const address = try std.net.Address.parseIp4("127.0.0.1", 9999);

    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;
    const listener = try posix.socket(address.any.family, tpe, protocol);

    defer posix.close(listener);

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &address.any, address.getOsSockLen());
    try posix.listen(listener, 128);

    var store = kv.Kv.init(allocator);
    defer store.deinit();

    var buf: [128]u8 = undefined;

    while (true) {
        var client_address: net.Address = undefined;
        var client_address_len: posix.socklen_t = @sizeOf(net.Address);

        const socket = posix.accept(listener, &client_address.any, &client_address_len, 0) catch |err | {
            std.debug.print("Accept failed: {any}\n", .{err});
            continue;
        };

        defer posix.close(socket);
        std.debug.print("connected {f}\n", .{client_address});

        const read = posix.read(socket, &buf) catch |err| {
            std.debug.print("Read failed: {any}\n", .{err});
            continue;
        };

        if (read == 0) {
            continue;
        }
        const line = buf[0..read];
        write(socket, line, &store) catch |err| {
            std.debug.print("Write failed: {any}\n", .{err});
        };
    }
}


fn write(socket: posix.socket_t, msg: []const u8, store: *kv.Kv) !void {
    const cmd = try command.parseCommand(msg);
    switch (cmd) {
        .Put => |put_cmd| {
            try store.put(put_cmd.key, put_cmd.value);
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
