const std = @import("std");

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
