const std = @import("std");
const Collector = @This();
//string collector
array_list: std.ArrayList(u8),
pub fn init(allocator: std.mem.Allocator) Collector {
    return Collector{ .array_list = std.ArrayList(u8).init(allocator) };
}
pub fn add(self: *Collector, ch: u8) !void {
    try self.array_list.append(ch);
}
pub fn deinit(self: *Collector) void {
    self.array_list.deinit();
}
