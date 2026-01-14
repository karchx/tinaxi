const std = @import("std");
const kv = @import("kv.zig");
const config = @import("config.zig");
const utils = @import("utils.zig");

const filename = "file_{}.db";

const DataFile = struct {
    id: u32,
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
            .id = index,
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
        try self.writer.seekFromEnd(0);

        const offset = self.writer.getPos();

        const sz = try self.writer.write(buf);

        self.currentWriterOffset += sz;

        return offset;
    }

    pub fn get(self: *DataFile, buf: []u8, value_pos: usize, value_size: usize) !void {
        try self.reader.seekTo(value_pos);
        const data = try self.reader.read(buf);

        if (data != value_size) {
            return error.ReadFailed;
        }
    }
};

pub const Store = struct {
    allocator: std.mem.Allocator,
    datafile: *DataFile,
    keydir: std.StringHashMap(kv.Metadata),
    mutex: std.Thread.Mutex,
    config: config.Options,

    pub fn init(allocator: std.mem.Allocator) !*Store {
        // init config
        const conf = config.defaultOptions();

        // init datafile
        var dir = try utils.openUserDir(conf.dir);
        defer dir.close();

        const keydir = std.StringHashMap(kv.Metadata).init(allocator);
        const store = try allocator.create(Store);

        store.* = .{
            .datafile = undefined,
            .allocator = allocator,
            .config = conf,
            .mutex = std.Thread.Mutex{},
            .keydir = keydir,
        };

        std.log.info("=========== Initializing Store ===========", .{});
        const id: u32 = 1; // TODO: get last datafile id
        store.datafile = try DataFile.init(allocator, id, dir);

        try store.loadKeyDir();

        try storeHashMap(store);

        std.log.info("=========== Store Initialized ===========", .{});

        return store;
    }

    pub fn deinit(self: *Store) void {
        self.keydir.deinit();
        self.datafile.deinit();
        self.allocator.destroy(self);

        self.storeHashMap() catch |err| {
            std.log.err("Failed to store hash map: {}", .{err});
        };
    }

    pub fn put(self: *Store, key: []const u8, value: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        // TODO: add validade record
        const rec = try kv.Kv.init(self.allocator, key, value);
        defer rec.deinit();

        const record_size = @sizeOf(kv.Kv) - @sizeOf([]u8) * 2 + rec.key_len + rec.value_len;
        const buf = try self.allocator.alloc(u8, record_size);
        defer self.allocator.free(buf);

        try rec.encode(buf);
        const offset = try self.datafile.put(buf);
        const metadata = kv.Metadata.init(self.datafile.id, record_size, offset, rec.timestamp);

        const entry = try self.keydir.getOrPut(key);

        if (!entry.found_existing) {
            const copy_key = try self.allocator.dupe(u8, key);
            entry.key_ptr.* = copy_key;
        }
        entry.value_ptr.* = metadata;
    }

    pub fn get(self: *Store, key: []const u8) !?[]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const metadata = self.keydir.get(key);
        std.log.info("Getting key: {s} metadata: {any}", .{key, metadata});
        if (metadata == null) {
            return undefined;
        }

        const buf = try self.allocator.alloc(u8, metadata.?.value_sz);
        defer self.allocator.free(buf);
        if (self.datafile.id == metadata.?.file_id) {
            try self.datafile.get(buf, metadata.?.value_offset, metadata.?.value_sz);
        } else {
            // oldfiles ?
        }
        const rec = try kv.decodeRecord(self.allocator, buf);
        defer rec.deinit();

        const value = try self.allocator.dupe(u8, rec.value);
        return value;
    }

    fn storeHashMap(self: *Store) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const path = try utils.openUserDir(self.config.dir);
        var file = try path.createFile(kv.HINTS_FILE, .{});
        defer file.close();

        var writer = file.writer(&.{}).interface;

        try writer.writeInt(u32, @as(u32, self.keydir.count()), .little);
        var it = self.keydir.iterator();

        while (it.next()) |entry| {
            try writer.writeInt(usize, @as(usize, entry.key_ptr.*.len), .little);
            try writer.writeAll(entry.key_ptr.*);

            const meta = entry.value_ptr.*;
            try writer.writeInt(u32, meta.file_id, .little);
            try writer.writeInt(usize, meta.value_sz, .little);
            try writer.writeInt(usize, meta.value_offset, .little);
            try writer.writeInt(i64, meta.timestamp, .little);
        }
    }

   fn loadKeyDir(self: *Store) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const path = try utils.openUserDir(self.config.dir);

        var file = path.openFile(kv.HINTS_FILE, .{}) catch |err| {
            std.log.info("Hints file not found with error: {}", .{err});
            return;
        };
        defer file.close();
        var buf: [1024]u8 = undefined;
        _ = file.reader(&buf);
        const stat = try file.stat();
        if (stat.size == 0) {
            return;
        }

        const entry_count = std.mem.readInt(u32, buf[0..4], .little);
        std.log.info("Loading {} entries into keydir", .{entry_count});
        var i: u32 = 0;
        while (i < entry_count) : (i += 1) {
            const key_len = entry_count;
            const key_buf = try self.allocator.alloc(u8, key_len);
            errdefer self.allocator.free(key_buf);

            // try reader.readNoEof(key_buf);

            // read metadata
            const file_id = std.mem.readInt(u32, buf[0..4], .little);
            const value_sz = std.mem.readInt(usize, buf[0..8], .little);
            const value_offset = std.mem.readInt(usize, buf[0..8], .little);
            const timestamp = std.mem.readInt(i64, buf[0..8], .little);

            const metadata = kv.Metadata.init(file_id, value_sz, value_offset, timestamp);
            std.log.info("Loaded key: {s} metadata: {any}", .{key_buf, metadata});
            try self.keydir.put(key_buf, metadata);
        }
        return;
    }
};
