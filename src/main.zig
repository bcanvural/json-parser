const std = @import("std");
const fs = std.fs;
const Syntaxtree = @import("syntraxtree.zig");
const print = std.debug.print;

const Error = error{
    InvalidJsonError,
    TreeAllocError,
};

fn process_value(str: []const u8, idx: *usize) Error!void {
    //consume value
    var closed = false;
    while (idx.* < str.len) {
        const ch = str[idx.*];
        idx.* += 1;
        switch (ch) {
            '"' => {
                closed = true;
                break;
            },
            else => {
                print("Inside else in process_value!\n", .{});
            },
        }
    }
    if (!closed) {
        return Error.InvalidJsonError;
    }
}
fn process_object(str: []const u8, idx: *usize, tree: *Syntaxtree, parent: *Syntaxtree.Node) Error!void {
    //consume "closing bracket"
    var closed = false;
    while (idx.* < str.len) {
        const ch = str[idx.*];
        idx.* += 1;
        switch (ch) {
            '}' => {
                closed = true;
                break;
            },
            '"' => {
                try process_value(str, idx);
            },
            else => {},
        }
    }
    if (!closed) {
        return Error.InvalidJsonError;
    }
    return;
}

pub fn parse_json(str: []u8) Error!void {
    if (str.len == 0) {
        return Error.InvalidJsonError;
    }

    const ally = std.heap.page_allocator;
    var tree = Syntaxtree.new(ally, Syntaxtree.Token.Object) catch return Error.TreeAllocError;
    tree.print_tr();

    var idx: usize = 0;
    while (idx < str.len) {
        const ch = str[idx];
        idx += 1;
        switch (ch) {
            '{' => {
                try process_object(
                    str,
                    &idx,
                    tree.root.?,
                );
                continue;
            },
            else => print("else\n", .{}),
        }
    }
}
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const ally = arena.allocator();

    const cwd_path = try std.fs.cwd().realpathAlloc(ally, ".");
    std.log.info("cwd: {s}", .{cwd_path});

    const file = try std.fs.cwd().openFile("tests/step2/valid.json", .{});
    const valid_json = try file.reader().readAllAlloc(ally, 1024);
    defer ally.free(valid_json);
    try parse_json(valid_json);
}

test "step1/invalid.json" {
    const file = try std.fs.cwd().openFile("tests/step1/invalid.json", .{});
    const ally = std.testing.allocator;
    const invalid_json = try file.reader().readAllAlloc(std.testing.allocator, 1024);
    defer ally.free(invalid_json);
    var err_returned = false;
    parse_json(invalid_json) catch |err| switch (err) {
        Error.InvalidJsonError => err_returned = true,
        else => return err,
    };
    try std.testing.expect(err_returned);
}

test "step1/valid.json" {
    const file = try std.fs.cwd().openFile("tests/step1/valid.json", .{});
    const ally = std.testing.allocator;
    const valid_json = try file.reader().readAllAlloc(ally, 1024);
    defer ally.free(valid_json);
    try parse_json(valid_json);
}

test "step2/valid.json" {
    const file = try std.fs.cwd().openFile("tests/step2/valid.json", .{});
    const ally = std.testing.allocator;
    const valid_json = try file.reader().readAllAlloc(ally, 1024);
    defer ally.free(valid_json);
    try parse_json(valid_json);
}
