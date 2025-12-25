// +-------------------+
// |   Command Layer   |  ← GET / SET / DEL / protocol
// +-------------------+
//
// This module provides a command layer for handling GET, SET, and DEL commands over a simple protocol.

const std = @import("std");
const poxis = std.posix;

pub const CommandTag = enum { Put, Get, Del };
pub const Command = union(CommandTag) {
    Put: struct { key: []const u8, value: []const u8 },
    Get: struct { key: []const u8 },
    Del: struct { key: []const u8 },
};

pub const RespTag = enum { Ok, Value, NotFound, Err };
pub const Response = union(RespTag) {
    Ok: void,
    Value: []const u8,
    NotFound: void,
    Err: []const u8,
};

pub fn parseCommand(input: []const u8) !Command {
    var it = std.mem.tokenizeAny(u8, input, " \t\r\n");
    const op = it.next() orelse return error.Empty;

    switch (std.ascii.toUpper(op[0])) {
        'P' => {
            const key = it.next() orelse return error.InvalidCommand;
            const rest = it.rest();
            if (rest.len == 0) return error.InvalidCommand;
            return Command{ .Put = .{ .key = key, .value = rest } };
        },
        'G' => {
            const key = it.next() orelse return error.InvalidCommand;
            return Command{ .Get = .{ .key = key } };
        },
        'D' => {
            const key = it.next() orelse return error.InvalidCommand;
            return Command{ .Get = .{ .key = key } };
        },
        else => return error.InvalidCommand,
    }
}

pub fn writeCommand(w: anytype, socket: poxis.socket_t, resp: Response) !void {
    switch (resp) {
        .Ok => {
            const msg = "OK\n";
            try handlerWrite(msg, socket, w);
        },
        .Value => |value| {
            try handlerWrite(value, socket, w);
        },
        .NotFound => {
            const msg = "NOT_FOUND\n";
            try handlerWrite(msg, socket, w);
        },
        .Err => |err_msg| {
            try handlerWrite(err_msg, socket, w);
        }
    }
}

fn handlerWrite(msg: []const u8, socket: poxis.socket_t, w: anytype) !void {
    var pos: usize = 0;
    while (pos < msg.len) {
        const written = try w(socket, msg[pos..]);
        if (written == 0) {
            return error.Closed;
        }
        pos += written;
    }
}
