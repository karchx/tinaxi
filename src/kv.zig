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

    pub fn set(self: *Kv, key: []const u8, value: []const u8) !void {
        if(self.store.fetchOrderedRemove(key)) |entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.value);
        }

        try self.store.put(
            try self.allocator.dupe(u8, key),
            try self.allocator.dupe(u8, value),
        );

    }

    pub fn get(self: *Kv, key: []const u8) ?[]const u8 {
        return self.store.get(key);
    }

    pub fn del(self: *Kv, key: []const u8) bool {
        if(self.store.fetchOrderedRemove(key)) |entry| {
            self.allocator.free(entry.value);
            return true;
        }
        return false;
    }
};


test "create a new kv store" {
    const allocator = std.testing.allocator;
    var kv = Kv.init(allocator);
    try std.testing.expect(kv.store.count() == 0);
}

test "set and get value" {
    const allocator = std.testing.allocator;
    var kv = Kv.init(allocator);
    defer kv.deinit();

    try kv.set("key1", "value1");
    try std.testing.expect(kv.store.count() == 1);

    const value = kv.get("key1");
    try std.testing.expect(std.mem.eql(u8, value orelse unreachable, "value1"));
}
