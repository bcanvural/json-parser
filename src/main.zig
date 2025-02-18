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
    StringField,
    NumField,
    Colon,
    ArrayOpen,
    ArrayClose,
    Comma,
};

fn process_string(str: []const u8, idx: *usize) !void {

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
        print("String was not closed\n", .{});
        return Error.InvalidJsonError;
    }
    const owned_str = try cc.get();
    defer ally.free(owned_str);

    print("printing collected value: {s}\n", .{owned_str});
}
fn process_number(str: []const u8, idx: *usize) !void {
    //we are here because we detected a digit
    //walk through until whitespace or :

    var closed = false;
    const ally = std.heap.page_allocator;
    var cc = char_collector.new(ally);
    defer cc.deinit();
    try cc.concat(str[idx.* - 1]); //starting by concatting detected digit

    loop: while (idx.* < str.len) {
        const ch = str[idx.*];
        idx.* += 1;
        switch (ch) {
            ':', ' ', ',', '}' => {
                closed = true;
                idx.* -= 1; //let these tokens be processed outside
                break :loop;
            },
            else => {
                try cc.concat(ch);
            },
        }
    }
    if (!closed) {
        print("Number was not closed\n", .{});
        return Error.InvalidJsonError;
    }

    const owned_str = try cc.get();
    defer ally.free(owned_str);

    print("printing collected value: {s}\n", .{owned_str});
}

test "custom/num.json" {
    print("------------\n", .{});
    const file = try std.fs.cwd().openFile("tests/custom/num.json", .{});
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

fn printList(list: std.ArrayList(Token)) void {
    for (list.items) |value| {
        switch (value) {
            Token.ObjectOpen => print("{{\n", .{}),
            Token.ObjectClose => print("}}\n", .{}),
            Token.ArrayOpen => print("[\n", .{}),
            Token.ArrayClose => print("]\n", .{}),
            Token.NumField => print("\"NUM\"\n", .{}),
            Token.StringField => print("\"STR\"\n", .{}),
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
                try process_string(str, &idx);
                try tokenList.append(Token.StringField);
            },
            ':' => {
                try tokenList.append(Token.Colon);
            },
            '}' => try tokenList.append(Token.ObjectClose),
            '[' => try tokenList.append(Token.ArrayOpen),
            ']' => try tokenList.append(Token.ArrayClose),
            ',' => try tokenList.append(Token.Comma),
            '0'...'9' => {
                try process_number(str, &idx);
                try tokenList.append(Token.NumField);
            },
            else => continue,
        }
    }

    printList(tokenList);
    // checks
    try paranthesis_check(allocator, tokenList);
    try colon_check(tokenList);
    //TODO comma check
}

//a colon can start earliest 3rd token
//a colon can only have a string field left of it.
//a colon can have {, [, stringfield, numfield to the right of it
fn colon_check(tokenList: std.ArrayList(Token)) !void {
    const len = tokenList.items.len;
    var colonFound = false;
    var fieldFound = false;
    for (tokenList.items, 0..) |token, i| {
        switch (token) {
            Token.StringField, Token.NumField => {
                fieldFound = true;
            },
            Token.Colon => {
                if (i < 2 or i == len - 1) {
                    return Error.InvalidJsonError;
                }
                colonFound = true;
                const left = tokenList.items[i - 1];
                const right = tokenList.items[i + 1];
                switch (left) {
                    Token.NumField => return Error.InvalidJsonError,
                    else => {},
                }
                switch (right) {
                    Token.ObjectOpen, Token.ArrayOpen, Token.StringField, Token.NumField => {},
                    else => return Error.InvalidJsonError,
                }
            },
            else => continue,
        }
    }
    //having one field means you gotta have colon too
    if (fieldFound and !colonFound) {
        print("Field was found but there was no colon!\n", .{});
        return Error.InvalidJsonError;
    }
}

test "custom colons tests" {
    for (1..5) |idx| {
        print("---Running Colon test {d}\n", .{idx});
        const ally = std.testing.allocator;
        const file_name = try std.fmt.allocPrint(ally, "tests/custom/colon{d}.json", .{idx});
        defer ally.free(file_name);
        const file = try std.fs.cwd().openFile(file_name, .{});
        const invalid_json = try file.reader().readAllAlloc(ally, 1024);
        defer ally.free(invalid_json);
        var err_returned = false;
        parse_json(ally, invalid_json) catch |err| switch (err) {
            Error.InvalidJsonError => err_returned = true,
            else => return err,
        };
        try std.testing.expect(err_returned);
    }
}

//below checks if open and close parantheses are balanced
fn paranthesis_check(allocator: std.mem.Allocator, tokenList: std.ArrayList(Token)) !void {
    var st = try Stack(Token).new(allocator);
    defer st.list.deinit();
    for (tokenList.items) |token| try switch (token) {
        Token.ObjectOpen => st.push(token),
        Token.ObjectClose => {
            const popped = try st.pop();
            if (popped != Token.ObjectOpen) {
                print("Unclosed object paranthesis\n", .{});
                return Error.InvalidJsonError;
            }
        },
        Token.ArrayOpen => st.push(token),
        Token.ArrayClose => {
            const popped = try st.pop();
            if (popped != Token.ArrayOpen) {
                print("Unclosed array paranthesis\n", .{});
                return Error.InvalidJsonError;
            }
        },
        else => continue,
    };
    //stack can only have elements if the parantheses were unbalanced!
    if (!st.empty()) {
        return Error.InvalidJsonError;
    }
}

test "paranthesis_checktest" {
    const ally = std.testing.allocator;
    var tokenList = std.ArrayList(Token).init(ally);
    defer tokenList.deinit();
    try tokenList.append(Token.ObjectOpen);
    try tokenList.append(Token.ObjectClose);
    try paranthesis_check(ally, tokenList);

    try tokenList.append(Token.ArrayOpen);
    var foundInvalidError = false;
    _ = paranthesis_check(ally, tokenList) catch |err| switch (err) {
        Error.InvalidJsonError => foundInvalidError = true,
        else => {},
    };

    try std.testing.expect(foundInvalidError);
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

//TODO next one to tackle
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
