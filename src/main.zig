const std = @import("std");
const fs = std.fs;
const stack = @import("stack.zig");
const print = std.debug.print;

const Error = error{
    InvalidJsonError,
    StringConcatMemoryError,
};
fn process_value(str: []const u8, idx: usize) Error!void {
    //consume value
    var closed = false;
    var local_idx: usize = 0;
    // TODO debug: collect until next "
    const allocator = std.heap.page_allocator;
    while (str[local_idx] != '\"') {}
}
fn process_object(str: []const u8, idx: usize) Error!void {
    //consume "closing bracket"
    var closed = false;
    var local_idx: usize = idx;
    for (str[idx..]) |ch| {
        switch (ch) {
            '}' => closed = true,
            '"' => process_value(str, local_idx),
            else => {},
        }
        local_idx += 1;
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
    var st = stack.Stack.init(ally);
    defer st.deinit();

    var idx: usize = 0;
    for (str) |ch| {
        print("{c}\n", .{ch});
        switch (ch) {
            '{' => try process_object(str, idx),
            else => print("else\n", .{}),
        }
        idx = idx + 1;
    }
}
pub fn main() !void {}

test "step1/invalid.json" {
    const file = try std.fs.cwd().openFile("tests/step1/invalid.json", .{});
    const ally = std.testing.allocator;
    const invalid_json = try file.reader().readAllAlloc(std.testing.allocator, 1024);
    defer ally.free(invalid_json);
    var err_returned = false;
    parse_json(invalid_json) catch |err| switch (err) {
        Error.InvalidJsonError => err_returned = true,
        Error.StringConcatMemoryError => return err,
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
