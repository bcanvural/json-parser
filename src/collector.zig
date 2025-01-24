const std = @import("std");
//string collector
pub const Collector = struct {
    array_list: std.ArrayList(u8),
    pub fn init(allocator: std.mem.Allocator) Collector {
        return Collector{ .array_list = std.ArrayList(u8).init(allocator) };
    }
    pub fn add(self: *Collector, ch: u8) !void {
        try self.array_list.append(ch);
    }
};
