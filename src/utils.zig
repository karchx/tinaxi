const std = @import("std");
const Crc32 = std.hash.Crc32;

pub fn listAllDatabaseFiles(allocator: std.mem.Allocator, dir: std.fs.Dir, out: *std.ArrayList([]const u8)) !void {
    var walker = try dir.walk(allocator);

    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (std.mem.endsWith(u8, entry.basename, ".db")) {
            const f = try allocator.dupe(u8, entry.basename);
            try out.append(allocator, f);
        }
    }
}

pub fn parseIdFromFilename(filename: []const u8) !u32 {
    const prefix = "file_";
    const suffix = ".db";
    const start_index = prefix.len;
    const end_index = std.mem.indexOf(u8, filename, suffix) orelse filename.len;

    if (start_index >= end_index) {
        std.debug.print("Invalid filename format: {s}\n", .{filename});
        return error.InvalidFilenameFormat;
    }

    const id_str = filename[start_index..end_index];

    const id = try std.fmt.parseInt(u32, id_str, 10);
    return id;
}

pub fn openUserDir(user_path: []const u8) !std.fs.Dir {
    if (std.fs.path.isAbsolute(user_path)) {
        return std.fs.openDirAbsolute(user_path, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => {
                try std.fs.makeDirAbsolute(user_path);
                return std.fs.openDirAbsolute(user_path, .{ .iterate = true });
            },
            else => return err,
        };
    } else {
        const cwd = std.fs.cwd();
        return cwd.openDir(user_path, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => {
                try cwd.makeDir(user_path);
                return cwd.openDir(user_path, .{ .iterate = true });
            },
            else => return err,
        };
    }
}

pub fn crc32Checksum(data: []const u8) u32 {
    var crc = Crc32.init();
    crc.update(data);
    return crc.final();
}
