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
    child.* = Node{ .children = null, .value = token };
    if (parent.children) |*children| {
        try children.append(child);
    } else {
        parent.children = std.ArrayList(*Node).init(self.allocator);
        try parent.children.?.append(child);
    }
}

pub fn print_tr(self: *Self) void {
    if (self.root) |root| {
        print_node(root, 0);
    } else {
        print("Tree is empty\n", .{});
    }
}

fn print_node(node: *Node, level: i32) void {
    switch (node.value) {
        Token.Object => print("Level: {d}, Object\n", .{level}),
        Token.KeyField => print("Level: {d}, KeyField\n", .{level}),
        Token.ValueField => print("Level: {d}, ValueField\n", .{level}),
        Token.Array => print("Level: {d}, Array\n", .{level}),
    }
    if (node.children) |children| {
        for (children.items) |child| {
            print_node(child, level + 1);
        }
    }
}
