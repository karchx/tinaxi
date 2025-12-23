// +-------------------+
// |   Command Layer   |  ← GET / SET / DEL / protocol
// +-------------------+
//
// This module provides a command layer for handling GET, SET, and DEL commands over a simple protocol.

const std = @import("std");

pub const CommandTag = enum { Put, Get, Del };
pub const Command = struct {
    Put: struct { key: []const u8, value: []const u8 },
    Get: struct { key: []const u8 },
    Del: struct { key: []const u8 },
};

pub const RespTag = enum { Ok, Value, NotFound, Err };
pub const Response = struct {
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

pub fn writeCommand(w: anytype, resp: Response) !void {
    switch (resp) {
        .Ok => try w.print("OK\n"),
        .Value => |value| try w.print("VALUE " ++ value ++ "\n"),
        .NotFound => try w.print("NOT_FOUND\n"),
        .Err => |err_msg| try w.print("ERR " ++ err_msg ++ "\n"),
    }
}
