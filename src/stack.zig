const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const print = std.debug.print;

pub const StackError = error{EmptyError};

pub fn Stack(comptime T: type) type {
    return struct {
        allocator: Allocator,
        list: ArrayList(T),

        pub fn new(allocator: Allocator) !Stack(T) {
            const list: std.ArrayList(T) = std.ArrayList(T).init(allocator);
            return .{
                .allocator = allocator,
                .list = list,
            };
        }

        pub fn deinit(this: *Stack(T)) void {
            this.list.deinit();
        }

        pub fn push(self: *Stack(T), element: T) !void {
            try self.list.append(element);
        }

        pub fn peek(self: *Stack(T)) StackError!T {
            const len = self.list.items.len;
            if (len == 0) {
                return StackError.EmptyError;
            }

            return self.list.items[self.list.items.len - 1];
        }

        pub fn pop(self: *Stack(T)) StackError!T {
            const len = self.list.items.len;
            if (len == 0) {
                return StackError.EmptyError;
            }
            const popped = self.list.items[len - 1];
            self.list.items.len -= 1;
            return popped;
        }
    };
}

test "stacktest" {
    const allocator = std.testing.allocator;
    var st = try Stack(i32).new(allocator);
    defer st.deinit();
    try st.push(1);
    try st.push(2);
    try st.push(3);
    const three = try st.peek();
    try std.testing.expectEqual(3, three);
    const popped = try st.pop();
    try std.testing.expectEqual(3, popped);
    const popped2 = try st.pop();
    try std.testing.expectEqual(2, popped2);
    try st.push(69);

    try std.testing.expectEqual(69, try st.peek());

    const popped3 = try st.pop();
    try std.testing.expectEqual(69, popped3);

    const popped4 = try st.pop();
    try std.testing.expectEqual(1, popped4);

    var gotError = false;
    _ = st.peek() catch {
        gotError = true;
    };
    try std.testing.expect(gotError);
    print("{d}\n", .{st.list.items.len});
}
