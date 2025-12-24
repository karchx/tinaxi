// +-------------------+
// |  Transport (TCP)  |  ← sockets, epoll, threads
// +-------------------+
//
// This module provides TCP transport functionality using sockets, epoll, and threads.

const std = @import("std");
const kv = @import("kv.zig");
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

        write(socket, buf[0..read]) catch |err| {
            std.debug.print("Write failed: {any}\n", .{err});
        };
    }
}


fn write(socket: posix.socket_t, msg: []const u8) !void {
    var pos: usize = 0;
    while (pos < msg.len) {
        const written = try posix.write(socket, msg[pos..]);
        if (written == 0) {
            return error.Closed;
        }
        pos += written;
   }
}
