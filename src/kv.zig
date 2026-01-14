const std = @import("std");
const utils = @import("utils.zig");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

pub const HINTS_FILE = "filedb.hints";

pub const Metadata = struct {
    file_id: u32,
    value_sz: usize,
    value_offset: usize,
    timestamp: i64,

    pub fn init(file_id: u32, value_sz: usize, value_offset: usize, timestamp: i64) Metadata {
        return .{
            .file_id = file_id,
            .value_sz = value_sz,
            .value_offset = value_offset,
            .timestamp = timestamp,
        };
    }
};

pub const Kv = struct {
    crc: u32,
    timestamp: i64,
    key_len: usize,
    value_len: usize,
    key: []const u8,
    value: []const u8,
    allocator: Allocator,

    pub fn init(allocator: Allocator, key: []const u8, value: []const u8) !*Kv {
        const kv = try allocator.create(Kv);
        const key_copy = try allocator.dupe(u8, key);
        const value_copy = try allocator.dupe(u8, value);

        kv.* = .{
            .crc = utils.crc32Checksum(key),
            .timestamp = std.time.timestamp(),
            .key_len = key.len,
            .value_len = value.len,
            .key = key_copy,
            .value = value_copy,
            .allocator = allocator,
        };

        return kv;
    }

    pub fn deinit(self: *Kv) void {
        self.allocator.free(self.key);
        self.allocator.free(self.value);
        self.allocator.destroy(self);
    }

    pub fn encode(self: *Kv, buf: []u8) !void {
        var fbs = std.io.fixedBufferStream(buf);
        const writer = fbs.writer();

        try writer.writeInt(u32, self.crc, std.builtin.Endian.little);
        try writer.writeInt(i64, self.timestamp, std.builtin.Endian.little);
        try writer.writeInt(usize, self.key_len, std.builtin.Endian.little);
        try writer.writeInt(usize, self.value_len, std.builtin.Endian.little);

        try writer.writeAll(self.key);
        try writer.writeAll(self.value);
    }
};

pub fn decodeRecord(allocator: Allocator, buf: []u8) !*Kv {
    var fbs = std.io.fixedBufferStream(buf);
    const reader = fbs.reader();

    _ = try reader.readInt(u32, std.builtin.Endian.little);
    _ = try reader.readInt(i64, std.builtin.Endian.little);
    const key_len = try reader.readInt(usize, std.builtin.Endian.little);
    const value_len = try reader.readInt(usize, std.builtin.Endian.little);
    const key = try allocator.alloc(u8, key_len);
    defer allocator.free(key);
    _ = try reader.read(key);
    const value = try allocator.alloc(u8, value_len);
    defer allocator.free(value);
    _ = try reader.read(value);
    return Kv.init(allocator, key, value);
}
