const std = @import("std");
const print = std.debug.print;

const Self = @This();

pub const Token = union(enum) {
    Object,
    KeyField,
    ValueField,
    Array,
};

pub const Node = struct {
    children: ?std.ArrayList(*Node),
    value: Token,
};

root: ?*Node,
allocator: std.mem.Allocator,

pub fn new(allocator: std.mem.Allocator, root_val: Token) !Self {
    var root_node = try allocator.create(Node);
    root_node.children = null;
    root_node.value = root_val;
    return .{ .root = root_node, .allocator = allocator };
}

//assuming parent is not null
pub fn lazyAddNode(self: *Self, parent: *Node, token: Token) !void {
    const child = try self.allocator.create(Node);
    if (parent.children) |children| {
        children.append(child);
    } else {
        parent.children = try std.ArrayList(token).init(self.allocator);
        parent.children.?.append(child);
    }
}

pub fn print_tr(self: *Self) void {
    if (self.root) |root| {
        print_node(root);
    } else {
        print("Tree is empty\n", .{});
    }
}

fn print_node(node: *Node) void {
    switch (node.value) {
        Token.Object => print("Object\n", .{}),
        Token.KeyField => print("KeyField\n", .{}),
        Token.ValueField => print("ValueField\n", .{}),
        Token.Array => print("Array\n", .{}),
    }
    if (node.children) |children| {
        for (children) |child| {
            print_node(child);
        }
    }
}
