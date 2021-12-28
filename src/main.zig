const std = @import("std");
const sql = @import("sql.zig");
const utils = @import("utils.zig");

const stdin = std.io.getStdIn().reader();

pub fn main() void {
    utils.print("hello world!\n", .{});
}
