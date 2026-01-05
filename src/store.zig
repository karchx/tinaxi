const std = @import("std");

const filename = "file_{}.db";

pub const Store = struct {
    writer: std.fs.File,
    reader: std.fs.File,
    mutex: std.Thread.Mutex,
    currentWriterOffset: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, index: u32, dir: std.fs.Dir) !*Store {
        var file_buf: [32]u8 = undefined;
        const file_name = try std.fmt.bufPrint(&file_buf, filename, .{index});
        _ = dir.createFile(file_name, .{ .read = true, .exclusive = true }) catch |err| switch (err) {
            error.PathAlreadyExists => {
                // open existing file
            },
            else => return err,
        };
        const file = try dir.openFile(file_name, .{ .mode = .read_write });

        const stat = try file.stat();
        const store = try allocator.create(Store);

        store.* = .{
            .writer = file,
            .reader = file,
            .mutex = std.Thread.Mutex{},
            .currentWriterOffset = stat.size,
            .allocator = allocator,
        };
        return store;
    }

    pub fn deinit(self: *Store) void {
        self.reader.close();

        self.allocator.destroy(self);
    }
};
