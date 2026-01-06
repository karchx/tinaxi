const std = @import("std");
const log = std.log;

// TODO: read conf or yaml file
pub const Options = struct {
    dir: []const u8,
    alwaysFsync: bool,
    log_level: log.Level,
    maxFileSize: usize,
    compactionInterval: u64,
    dfRotationInterval: u64,
    syncInterval: u64,
};

pub fn defaultOptions() Options {
    return Options{
        .dir = "/home/stivarch/src/projects/tinaxi/filedb",
        .alwaysFsync = false,
        .log_level = log.Level.info,
        .maxFileSize = 1024 * 1024 * 10, // 10 MB
        .compactionInterval = 10,
        .dfRotationInterval = 15, // 24 hours
        .syncInterval = 15
    };
}
