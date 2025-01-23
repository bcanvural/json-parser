const std = @import("std");

pub const Stack = struct {
    array_list: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) Stack {
        return Stack{ .array_list = std.ArrayList(u8).init(allocator) };
    }
    pub fn push(self: *Stack, item: u8) !void {
        try self.array_list.append(item);
    }

    pub fn pop(self: *Stack) u8 {
        return self.array_list.pop();
    }

    pub fn peek(self: *Stack) u8 {
        return self.array_list.items[self.len() - 1];
    }

    pub fn len(self: *Stack) usize {
        return self.array_list.items.len;
    }
    pub fn deinit(self: *Stack) void {
        return self.array_list.deinit();
    }
};

test "stack tests" {
    const ally = std.testing.allocator;
    var stack = Stack.init(ally);
    defer stack.deinit();

    try std.testing.expect(stack.len() == 0);

    try stack.push('a');
    try stack.push('b');
    try stack.push('c');

    try std.testing.expect(stack.peek() == 'c');
    try std.testing.expect(stack.peek() == 'c');

    try std.testing.expect(stack.len() == 3);
    try std.testing.expect(stack.pop() == 'c');
    try std.testing.expect(stack.len() == 2);
    try std.testing.expect(stack.pop() == 'b');
    try std.testing.expect(stack.len() == 1);
    try std.testing.expect(stack.pop() == 'a');
    try std.testing.expect(stack.len() == 0);
}
