const std = @import("std");
const print = std.debug.print;

pub fn SyntaxTree(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const Node = struct { child: ?*Node, value: T };
        pub const Error = error{
            AllocationError,
        };
        allocator: std.mem.Allocator,
        root: ?*Node,
        pub fn new(allocator: std.mem.Allocator, root_val: T) Error!Self {
            var root = allocator.create(Node) catch return Error.AllocationError;
            root.child = null;
            root.value = root_val;
            return .{
                .allocator = allocator,
                .root = root,
            };
        }

        pub fn print_tr(self: *Self) void {
            if (self.root) |root| {
                print_node(root);
            } else {
                print("Tree is empty\n", .{});
            }
        }
        fn print_node(node: *Node) void {
            print("Node value: {s}\n", .{node.value}); //Using s for debugging for now
            if (node.child) |child| {
                print_node(child);
            }
        }
    };
}
