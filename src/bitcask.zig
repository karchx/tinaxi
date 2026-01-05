const std = @import("std");

const RecordHeader = struct {
    crc32: u32,
    timestamp: i64,
    key_sz: u32,
    value_sz: u32,

    pub fn size() usize {
        return @sizeOf(u32) * 3 + @sizeOf(i64);
    }
};

pub const Storage = struct {
    file: std.fs.File,
    allocator: std.mem.Allocator,

    pub fn append(self: *Storage, key: []const u8, value: []const u8) !u64 {
        const offset = try self.file.getEndPos();

        const header = RecordHeader{
            .crc32 = 0,
            .timestamp = std.time.timestamp(),
            .key_sz = @intCast(key.len),
            .value_sz = @intCast(value.len),
        };

        var writer = self.file.writer();
        try writer.writeStruct(header);
        try writer.writeAll(key);
        try writer.writeAll(value);

        return offset;
    }
};
