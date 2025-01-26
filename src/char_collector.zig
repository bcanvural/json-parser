//char collector
const std = @import("std");

const Self = @This();

list: std.ArrayList(u8),
allocator: std.mem.Allocator,

pub fn new(allocator: std.mem.Allocator) !Self {
    const list = try std.ArrayList(u8).init(allocator);
    return .{
        .allocator = allocator,
        .list = list,
    };
}

pub fn concat(self: *Self, ch: u8) !void {
    try self.list.append(ch);
}

pub fn get(self: *Self) ![]u8 {
    return try self.list.toOwnedSlice();
}

pub fn deinit(self: *Self) void {
    self.list.deinit();
}
