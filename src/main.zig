const std = @import("std");
const fs = std.fs;
const char_collector = @import("char_collector.zig");
const print = std.debug.print;
const Stack = @import("stack.zig").Stack;

const Error = error{
    InvalidJsonError,
};

pub const Token = union(enum) {
    ObjectOpen,
    ObjectClose,
    Field,
    Colon,
    ArrayOpen,
    ArrayClose,
    Comma,
};

fn process_field(str: []const u8, idx: *usize) !void {

    //consume value
    var closed = false;
    const ally = std.heap.page_allocator;
    var cc = char_collector.new(ally);
    defer cc.deinit();
    loop: while (idx.* < str.len) {
        const ch = str[idx.*];
        idx.* += 1;
        switch (ch) {
            '"' => {
                closed = true;
                break :loop;
            },
            else => {
                try cc.concat(ch);
            },
        }
    }
    if (!closed) {
        return Error.InvalidJsonError;
    }
    const owned_str = try cc.get();
    defer ally.free(owned_str);

    print("printing collected value: {s}\n", .{owned_str});
}

fn printList(list: std.ArrayList(Token)) void {
    for (list.items) |value| {
        switch (value) {
            Token.ObjectOpen => print("{{\n", .{}),
            Token.ObjectClose => print("}}\n", .{}),
            Token.ArrayOpen => print("[\n", .{}),
            Token.ArrayClose => print("]\n", .{}),
            Token.Field => print("\"field\"\n", .{}),
            Token.Colon => print(":\n", .{}),
            Token.Comma => print(",\n", .{}),
        }
    }
}
pub fn parse_json(allocator: std.mem.Allocator, str: []u8) !void {
    if (str.len == 0) {
        return Error.InvalidJsonError;
    }

    var tokenList = std.ArrayList(Token).init(allocator);
    defer tokenList.deinit();

    var idx: usize = 0;
    while (idx < str.len) {
        const ch = str[idx];
        idx += 1;
        switch (ch) {
            '{' => try tokenList.append(Token.ObjectOpen),
            '"' => {
                try process_field(str, &idx);
                try tokenList.append(Token.Field);
            },
            ':' => {
                try tokenList.append(Token.Colon);
            },
            '}' => try tokenList.append(Token.ObjectClose),
            '[' => try tokenList.append(Token.ArrayOpen),
            ']' => try tokenList.append(Token.ArrayClose),
            ',' => try tokenList.append(Token.Comma),
            else => continue,
        }
    }

    printList(tokenList);
    //checks
    // try paranthesis_check(allocator, tokenList);
}
// fn paranthesis_check(allocator: std.mem.Allocator, tokenList: std.ArrayList(Token)) !bool {
//     const st = Stack(T.new(allocator);
//     try tokenList.append(Token.ObjectOpen);
//     printList(tokenList);
//     defer st.list.deinit();
// }

test "step2/invalid.json" {
    print("------------\n", .{});
    const file = try std.fs.cwd().openFile("tests/step2/invalid.json", .{});
    const ally = std.testing.allocator;
    const invalid_json = try file.reader().readAllAlloc(ally, 1024);
    defer ally.free(invalid_json);
    var err_returned = false;
    parse_json(ally, invalid_json) catch |err| switch (err) {
        Error.InvalidJsonError => err_returned = true,
        else => return err,
    };
    try std.testing.expect(err_returned);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const cwd_path = try std.fs.cwd().realpathAlloc(allocator, ".");
    std.log.info("cwd: {s}", .{cwd_path});

    const file = try std.fs.cwd().openFile("tests/step2/valid.json", .{});
    const valid_json = try file.reader().readAllAlloc(allocator, 1024);
    defer allocator.free(valid_json);
    try parse_json(allocator, valid_json);
}

test "step1/invalid.json" {
    print("------------\n", .{});
    const file = try std.fs.cwd().openFile("tests/step1/invalid.json", .{});
    const ally = std.testing.allocator;
    const invalid_json = try file.reader().readAllAlloc(std.testing.allocator, 1024);
    defer ally.free(invalid_json);
    var err_returned = false;
    parse_json(ally, invalid_json) catch |err| switch (err) {
        Error.InvalidJsonError => err_returned = true,
        else => return err,
    };
    try std.testing.expect(err_returned);
}

test "step1/valid.json" {
    print("------------\n", .{});
    const file = try std.fs.cwd().openFile("tests/step1/valid.json", .{});
    const ally = std.testing.allocator;
    const valid_json = try file.reader().readAllAlloc(ally, 1024);
    defer ally.free(valid_json);
    try parse_json(ally, valid_json);
}

test "step2/invalid2.json" {
    print("------------\n", .{});
    const file = try std.fs.cwd().openFile("tests/step2/invalid2.json", .{});
    const ally = std.testing.allocator;
    const invalid_json = try file.reader().readAllAlloc(ally, 1024);
    defer ally.free(invalid_json);
    var err_returned = false;
    parse_json(ally, invalid_json) catch |err| switch (err) {
        Error.InvalidJsonError => err_returned = true,
        else => return err,
    };
    try std.testing.expect(err_returned);
}

//removing this test breaks the testing plugin lol
//probably because it includes Stack that way
test "stacktest" {
    const allocator = std.testing.allocator;
    var st = try Stack(i32).new(allocator);
    defer st.deinit();
    try st.push(1);
    try st.push(2);
    try st.push(3);
    const three = try st.peek();
    try std.testing.expectEqual(3, three);
    print("itemslength: {d}\n", .{st.list.items.len});
}

test "step2/valid.json" {
    print("------------\n", .{});
    const file = try std.fs.cwd().openFile("tests/step2/valid.json", .{});
    const ally = std.testing.allocator;
    const valid_json = try file.reader().readAllAlloc(ally, 1024);
    defer ally.free(valid_json);
    try parse_json(ally, valid_json);
}

test "step2/valid2.json" {
    print("------------\n", .{});
    const file = try std.fs.cwd().openFile("tests/step2/valid2.json", .{});
    const ally = std.testing.allocator;
    const valid_json = try file.reader().readAllAlloc(ally, 1024);
    defer ally.free(valid_json);
    try parse_json(ally, valid_json);
}

test "step3/invalid.json" {
    print("------------\n", .{});
    const file = try std.fs.cwd().openFile("tests/step3/invalid.json", .{});
    const ally = std.testing.allocator;
    const invalid_json = try file.reader().readAllAlloc(ally, 1024);
    defer ally.free(invalid_json);
    var err_returned = false;
    parse_json(ally, invalid_json) catch |err| switch (err) {
        Error.InvalidJsonError => err_returned = true,
        else => return err,
    };
    try std.testing.expect(err_returned);
}
