const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Kv = struct {
    allocator: Allocator,
    store: std.StringArrayHashMap([]const u8),

    pub fn init(allocator: Allocator) Kv {
        return .{ .allocator = allocator, .store = std.StringArrayHashMap([]const u8).init(allocator) };
    }

    pub fn deinit(self: *Kv) void {
        var iterator = self.store.iterator();
        while (iterator.next()) | entry | {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.store.deinit();
    }

    pub fn put(self: *Kv, key: []const u8, value: []const u8) !void {
        if(self.store.fetchOrderedRemove(key)) |entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.value);
        }

        try self.store.put(
            try self.allocator.dupe(u8, key),
            try self.allocator.dupe(u8, value),
        );

    }
};


test "create a new kv store" {
    const allocator = std.testing.allocator;
    var kv = Kv.init(allocator);
    try std.testing.expect(kv.store.count() == 0);
}

test "puts value" {
    try std.testing.expect(true);
}
