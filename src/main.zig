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
    TrueField,
    FalseField,
    NullField,
    Colon,
    ArrayOpen,
    ArrayClose,
    Comma,
};

pub const ObjectParseToken = union(enum) {
    KeyField,
    ValueField,
    Colon,
    Comma,
};

pub const ArrayParseToken = union(enum) {
    ObjectField,
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
fn isNumber(str: []const u8) bool {
    var foundNumber = true;
    _ = std.fmt.parseInt(i64, str, 10) catch {
        _ = std.fmt.parseFloat(f64, str) catch {
            foundNumber = false;
        };
    };

    return foundNumber;
}
//From RFC: A json value must be an object, array, number, or string, or one of the following three literal names:
//false, null, true
//below we only check for number, false, null, true
fn process_value(str: []const u8, idx: *usize) !Token {
    var closed = false;
    const ally = std.heap.page_allocator;
    var cc = char_collector.new(ally);
    defer cc.deinit();
    try cc.concat(str[idx.* - 1]); //starting by concatting detected digit

    loop: while (idx.* < str.len) {
        const ch = str[idx.*];
        idx.* += 1;
        switch (ch) {
            ':', ' ', ',', '}', '\n', '\r' => {
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
        print("Value was not closed\n", .{});
        return Error.InvalidJsonError;
    }

    const owned_str = try cc.get();
    print("printing collected value: {s}\n", .{owned_str});
    defer ally.free(owned_str);

    if (isNumber(owned_str)) {
        return Token.NumField;
    }

    if (std.mem.eql(u8, owned_str, "true")) {
        return Token.TrueField;
    } else if (std.mem.eql(u8, owned_str, "false")) {
        return Token.FalseField;
    } else if (std.mem.eql(u8, owned_str, "null")) {
        return Token.NullField;
    } else {
        return Error.InvalidJsonError;
    }
}

fn printList(list: *std.ArrayList(Token)) void {
    for (list.items) |value| {
        printToken(value);
    }
}
fn printToken(token: Token) void {
    switch (token) {
        Token.ObjectOpen => print("{{\n", .{}),
        Token.ObjectClose => print("}}\n", .{}),
        Token.ArrayOpen => print("[\n", .{}),
        Token.ArrayClose => print("]\n", .{}),
        Token.NumField => print("\"NUM\"\n", .{}),
        Token.StringField => print("\"STR\"\n", .{}),
        Token.TrueField => print("\"TRUE\"\n", .{}),
        Token.FalseField => print("\"FALSE\"\n", .{}),
        Token.NullField => print("\"NULL\"\n", .{}),
        Token.Colon => print(":\n", .{}),
        Token.Comma => print(",\n", .{}),
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
            '{' => {
                try tokenList.append(Token.ObjectOpen);
            },
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
            '0'...'9', 'a'...'z', 'A'...'Z' => {
                const value = try process_value(str, &idx);
                try tokenList.append(value);
            },
            else => continue,
        }
    }

    printList(&tokenList);
    // checks
    try paranthesis_check(allocator, tokenList);
    // try colon_check(tokenList);
    // try comma_check(tokenList);
    try parseTokenList(allocator, &tokenList);
}

fn parseArray(tokenList: *std.ArrayList(Token), idx: *usize) !void {
    // const len = tokenList.items.len;
    _ = tokenList;
    _ = idx;

    return;
}
fn parseObject(allocator: std.mem.Allocator, tokenList: *std.ArrayList(Token), idx: *usize) !void {
    const len = tokenList.items.len;
    var firstPassList = std.ArrayList(ObjectParseToken).init(allocator);
    defer firstPassList.deinit();
    //first pass: we make a pass and recursively resolve all tokens into key, value, comma or colon fields.
    while (idx.* < len) {
        const token = tokenList.items[idx.*];
        idx.* += 1; // we increment by default, handle unique cases separately
        switch (token) {
            Token.StringField, Token.NumField, Token.TrueField, Token.FalseField, Token.NullField => {
                //are we key or or we value?
                //if we are stringfield and if we have a colon to our right we are key otherwise we are value
                if (token == Token.StringField) {
                    const r_index = idx.*;
                    if (r_index != len) {
                        const right = tokenList.items[r_index];
                        if (right == Token.Colon) {
                            try firstPassList.append(ObjectParseToken.KeyField);
                            continue;
                        }
                    }
                }
                try firstPassList.append(ObjectParseToken.ValueField);
            },
            Token.Colon => try firstPassList.append(ObjectParseToken.Colon),
            Token.Comma => try firstPassList.append(ObjectParseToken.Comma),
            Token.ArrayOpen => {
                try parseArray(tokenList, idx);
                //if we survived above we can add this as a value field!
                try firstPassList.append(ObjectParseToken.ValueField);
            },
            Token.ObjectOpen => {
                try parseObject(allocator, tokenList, idx);
                //if we survived above  we can add this as a value field!
                try firstPassList.append(ObjectParseToken.ValueField);
            },
            Token.ObjectClose => {
                print("In Object close\n", .{});
                continue;
            },
            Token.ArrayClose => {
                print("in array close, this should never happen if parantheses are balanced", .{});
                return Error.InvalidJsonError;
            },
        }
    }

    //second pass: we expect to see one of the following: {}, {key:value}, {key:value,key:value}, {key:value, key:value, key:value}... and so on
    const firstPassListLen = firstPassList.items.len;

    if (firstPassListLen == 0) {
        return; //empty object is valid
    }
    if (firstPassListLen == 1 or firstPassListLen == 2) {
        //we can never have only 1 or 2, something's fishy
        return Error.InvalidJsonError;
    }
    var s_idx: usize = 0;

    while (s_idx <= firstPassListLen - 1) {
        const key_idx = s_idx;
        const key = firstPassList.items[key_idx];
        if (key != ObjectParseToken.KeyField) {
            return Error.InvalidJsonError;
        }
        //
        const colon_idx = key_idx + 1;
        if (colon_idx == firstPassListLen) {
            return Error.InvalidJsonError;
        }
        const colon = firstPassList.items[colon_idx];
        if (colon != ObjectParseToken.Colon) {
            return Error.InvalidJsonError;
        }
        //
        const value_idx = colon_idx + 1;
        if (value_idx == firstPassListLen) {
            return Error.InvalidJsonError;
        }
        const value = firstPassList.items[s_idx + 2];
        if (value != ObjectParseToken.ValueField) {
            return Error.InvalidJsonError;
        }
        //
        //should we check for comma?
        //"only if we are not the last key:value"
        //key:value are 3 tokens. 3 + 3 + 1comma = 7
        if (s_idx + 7 <= firstPassListLen) {
            const comma = firstPassList.items[s_idx + 3];
            if (comma != ObjectParseToken.Comma) {
                return Error.InvalidJsonError;
            }
            s_idx += 4;
        } else {
            s_idx += 3;
        }
    }
    //third pass: make sure the commas are placed right.
    //each comma must have a value on the left, and a key on the right. no exceptions
    //problem: non-existence of commas can't be checked this way
    for (firstPassList.items, 0..) |token, tp_idx| {
        switch (token) {
            ObjectParseToken.Comma => {
                //bounds checks:
                const l_idx = tp_idx - 1;
                const r_idx = tp_idx + 1;
                if (l_idx < 0 or r_idx > firstPassListLen - 1) {
                    return Error.InvalidJsonError;
                }
                const left = firstPassList.items[l_idx];
                const right = firstPassList.items[r_idx];
                if (left != ObjectParseToken.ValueField and right != ObjectParseToken.KeyField) {
                    return Error.InvalidJsonError;
                }
            },
            else => {},
        }
    }
}
test "step2/valid.json" {
    print("------------\n", .{});
    const file = try std.fs.cwd().openFile("tests/step2/valid.json", .{});
    const ally = std.testing.allocator;
    const valid_json = try file.reader().readAllAlloc(ally, 1024);
    defer ally.free(valid_json);
    try parse_json(ally, valid_json);
}
test "custom/colon5.json" {
    print("------------\n", .{});
    const file = try std.fs.cwd().openFile("tests/custom/colon5.json", .{});
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
//todo debug new parsing method
fn parseTokenList(allocator: std.mem.Allocator, tokenList: *std.ArrayList(Token)) !void {
    if (tokenList.items.len == 0) {
        return Error.InvalidJsonError;
    }
    const first = tokenList.items[0];
    var idx: usize = 1;
    switch (first) {
        Token.ObjectOpen => try parseObject(allocator, tokenList, &idx),
        // Token.ArrayOpen => try parseArray(tokenList, &idx),
        else => return Error.InvalidJsonError,
    }
}

//a colon can start earliest 3rd token
//a colon can only have a string field left of it.
//a colon can have {, [, stringfield, numfield to the right of it
fn colon_check(tokenList: std.ArrayList(Token)) !void {
    const len = tokenList.items.len;
    for (tokenList.items, 0..) |token, i| {
        switch (token) {
            Token.StringField, Token.NumField => {
                if (i == 0 or i == len - 1) {
                    return Error.InvalidJsonError;
                }
                //to the left or right, a token cannot exist it should've been a colon!
                const left = tokenList.items[i - 1];
                switch (left) {
                    Token.StringField, Token.FalseField, Token.TrueField, Token.NullField => {
                        return Error.InvalidJsonError;
                    },
                    else => {},
                }
                const right = tokenList.items[i + 1];
                switch (right) {
                    Token.StringField, Token.FalseField, Token.TrueField, Token.NullField, Token.ArrayOpen, Token.ObjectOpen => {
                        return Error.InvalidJsonError;
                    },
                    else => {},
                }
            },
            Token.Colon => {
                if (i < 2 or i == len - 1) {
                    return Error.InvalidJsonError;
                }
                const left = tokenList.items[i - 1];
                const right = tokenList.items[i + 1];
                switch (left) {
                    Token.StringField => {},
                    else => return Error.InvalidJsonError,
                }
                switch (right) {
                    Token.ObjectOpen, Token.ArrayOpen, Token.StringField, Token.NumField, Token.NullField, Token.TrueField, Token.FalseField => {},
                    else => return Error.InvalidJsonError,
                }
            },
            else => continue,
        }
    }
}

test "custom colons tests" {
    for (1..7) |idx| {
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
test "step3/valid.json" {
    print("------------\n", .{});
    const file = try std.fs.cwd().openFile("tests/step3/valid.json", .{});
    const ally = std.testing.allocator;
    const valid_json = try file.reader().readAllAlloc(ally, 1024);
    defer ally.free(valid_json);
    try parse_json(ally, valid_json);
}
test "step4/invalid.json" {
    print("------------\n", .{});
    const file = try std.fs.cwd().openFile("tests/step4/invalid.json", .{});
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
test "step4/valid.json" {
    print("------------\n", .{});
    const file = try std.fs.cwd().openFile("tests/step4/valid.json", .{});
    const ally = std.testing.allocator;
    const valid_json = try file.reader().readAllAlloc(ally, 1024);
    defer ally.free(valid_json);
    try parse_json(ally, valid_json);
}
test "step4/valid2.json" {
    print("------------\n", .{});
    const file = try std.fs.cwd().openFile("tests/step4/valid2.json", .{});
    const ally = std.testing.allocator;
    const valid_json = try file.reader().readAllAlloc(ally, 1024);
    defer ally.free(valid_json);
    try parse_json(ally, valid_json);
}
