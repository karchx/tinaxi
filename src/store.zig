const std = @import("std");
const kv = @import("kv.zig");
const config = @import("config.zig");
const utils = @import("utils.zig");

const filename = "file_{}.db";

const DataFile = struct {
    writer: std.fs.File,
    reader: std.fs.File,
    mutex: std.Thread.Mutex,
    currentWriterOffset: u64,
    alloctor: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, index: u32, dir: std.fs.Dir) !*DataFile {
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
        const df = try allocator.create(DataFile);
        df.* = .{
            .writer = file,
            .reader = file,
            .mutex = std.Thread.Mutex{},
            .currentWriterOffset = stat.size,
            .alloctor = allocator,
        };
        return df;
    }

    pub fn deinit(self: *DataFile) void {
        self.writer.close();
        self.reader.close();
        self.alloctor.destroy(self);
    }

    pub fn put(self: *DataFile, buf: []const u8) !u64 {
        const sz = try self.writer.write(buf);

        const offset = self.currentWriterOffset;
        self.currentWriterOffset += sz;

        return offset;
    }
};

pub const Store = struct {
    allocator: std.mem.Allocator,
    datafile: *DataFile,
    keydir: std.StringHashMap(kv.Metadata),
    mutex: std.Thread.Mutex,
    config: config.Options,

    // KV RECORD
    // TODO: move to separate struct in kv.zig
    crc: u32,
    timestamp: i64,
    key_len: usize,
    value_len: usize,
    key: []const u8,
    value: []const u8,

    pub fn init(allocator: std.mem.Allocator, key: []const u8, value: []const u8) !*Store {
        // init config
        const conf = config.defaultOptions();

        // init datafile
        var dir = try utils.openUserDir(conf.dir);
        defer dir.close();

        const keydir = std.StringHashMap(kv.Metadata).init(allocator);

        const store = try allocator.create(Store);

        // init record
        const key_copy = try allocator.dupe(u8, key);
        const value_copy = try allocator.dupe(u8, value);

        store.* = .{
            .allocator = allocator,
            .config = conf,

            .crc = 0,
            .timestamp = std.time.timestamp(),
            .keydir = keydir,
            .key_len = key.len,
            .value_len = value.len,
            .key = key_copy,
            .value = value_copy,
        };

        std.log.info("=========== Initializing Store ===========", .{});
        const id: u32 = 1; // TODO: get last datafile id
        store.datafile = try DataFile.init(allocator, id, dir);
        try store.loadKeyDir();
        std.log.info("=========== Store Initialized ===========", .{});

        return store;
    }

    pub fn deinit(self: *Store) void {
        self.allocator.free(self.key);
        self.allocator.free(self.value);
        self.allocator.destroy(self);
    }

    pub fn put(self: *Store, buf: []const u8) !u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return buf;
    }

    pub fn encode(self: *Store, buf: []u8) !void {
        var fbs = std.io.fixedBufferStream(buf);
        const writer = fbs.writer();

        try writer.writeInt(u32, self.crc, std.builtin.Endian.little);
        try writer.writeInt(i64, self.timestamp, std.builtin.Endian.little);
        try writer.writeInt(usize, self.key_len, std.builtin.Endian.little);
        try writer.writeInt(usize, self.value_len, std.builtin.Endian.little);

        try writer.writeAll(self.key);
        try writer.writeAll(self.value);
    }

    pub fn loadKeyDir(self: *Store) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const path = try utils.openUserDir(self.config.dir);

        var file = path.openFile(kv.HINTS_FILE, .{}) catch |err| {
            std.log.info("Hints file not found with error: {}", .{err});
            return;
        };
        defer file.close();
        var reader = file.reader();
        const stat = try file.stat();
        if (stat.size == 0) {
            return;
        }

        const entry_count = try reader.readInt(u32, std.builtin.Endian.little);
        var i: u32 = 0;
        while (i < entry_count) : (i += 1) {
            const key_len = try reader.readInt(usize, std.builtin.Endian.little);
            const key_buf = try self.allocator.alloc(u8, key_len);
            errdefer self.allocator.free(key_buf);
            try reader.readNoEof(key_buf);

            // read metadata
            const file_id = try reader.readInt(u32, std.builtin.Endian.little);
            const value_sz = try reader.readInt(usize, std.builtin.Endian.little);
            const value_offset = try reader.readInt(usize, std.builtin.Endian.little);
            const timestamp = try reader.readInt(i64, std.builtin.Endian.little);

            const metadata = kv.Metadata.init(file_id, value_sz, value_offset, timestamp);
            try self.keydir.put(key_buf, metadata);
        }
        return;
    }
};
