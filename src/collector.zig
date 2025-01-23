const std = @import("std");
//string collector
pub const Collector = struct {
    array_list: std.ArrayList(u8),
    pub fn init(allocator: std.mem.Allocator) Collector {
        return Collector{ .array_list = std.ArrayList(u8).init(allocator) };
    }
};
