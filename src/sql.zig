const std = @import("std");
const zdb = @import("zdb");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

var sql_allocator: *Allocator = undefined;
var connection: zdb.DBConnection = undefined;

const CONNECTION_STR = "DRIVER={Oracle 21 ODBC driver};DBQ=oracle0.ugr.es:1521/practbd.oracle0.ugr.es;UID=x7034014;PWD=x7034014;";

pub fn init(allocator: *Allocator, connection_string: []const u8) !void {
    sql_allocator = allocator;

    connection = try zdb.DBConnection.initWithConnectionString(CONNECTION_STR);
    try connection.setCommitMode(.manual);
}

pub fn deinit() void {
    connection.deinit();
    if (lastError) |err| {
        err.deinit();
        lastError = null;
    }
}

pub fn getAllocator() *Allocator {
    return sql_allocator;
}

var lastError: ?SqlError = null;

pub const SqlError = struct {
    code: i32,
    msg: []const u8,

    fn fromCursor(cursor: *zdb.Cursor) !SqlError {
        // Get cursor errors
        const errors = cursor.getErrors();
        defer {
            for (errors) |*err| {
                err.deinit(cursor.allocator);
            }
            cursor.allocator.free(errors);
        }

        // Duplicate the first error message
        assert(errors.len == 1);
        const err = errors[0];
        const error_msg_copy = blk: {
            // Provided length seems to be twice the real length. We substract 1
            // to remove newline character.
            const msg_len = @divExact(err.error_message.len, 2) - 1;
            const i = if (std.mem.indexOfScalar(u8, err.error_message, ':')) |idx| idx + 2 else 0;
            break :blk try sql_allocator.dupe(u8, err.error_message[i..msg_len]);
        };

        // Create the SqlError
        return SqlError{
            .code = err.error_code,
            .msg = error_msg_copy,
        };
    }

    pub fn deinit(self: SqlError) void {
        sql_allocator.free(self.msg);
    }
};

// Caller is responsible of freeing SqlError calling deinit
pub fn getLastError() SqlError {
    const err = lastError orelse std.debug.panic("attempted to get lastError when there isn't any\n", .{});
    lastError = null;
    return err;
}

// Caller is not the owner of the memory and should not free it
// pub fn getLastError() []const u8 {
//     return lastError orelse std.debug.panic("attempted to get lastError when there isn't any\n", .{});
// }

fn getAndSetLastError(cursor: *zdb.Cursor) !void {
    setLastError(try SqlError.fromCursor(cursor));
}

fn setLastError(err: SqlError) void {
    if (lastError) |old_err| {
        old_err.deinit();
    }
    lastError = err;
}

pub fn execute(comptime statement: []const u8, params: anytype) !void {
    var cursor = try connection.getCursor(sql_allocator);
    defer cursor.deinit() catch unreachable;

    const sql_query = if (params.len > 0) try std.fmt.allocPrint(sql_allocator, statement, params) else statement;
    defer if (params.len > 0) sql_allocator.free(sql_query);

    _ = cursor.statement.executeDirect(sql_query) catch |err| {
        try getAndSetLastError(&cursor);
        return err;
    };
}

pub fn query(comptime StructType: type, comptime statement: []const u8, params: anytype) ![]StructType {
    var cursor = try connection.getCursor(sql_allocator);
    defer cursor.deinit() catch unreachable;

    const sql_query = if (params.len > 0) try std.fmt.allocPrint(sql_allocator, statement, params) else statement;
    defer if (params.len > 0) sql_allocator.free(sql_query);

    var tuplas = cursor.executeDirect(StructType, .{}, sql_query) catch |err| {
        try getAndSetLastError(&cursor);
        return err;
    };
    defer tuplas.deinit();

    // TODO para liberar esto tienes que usar el allocator del cursor..
    return tuplas.getAllRows();
}

pub fn querySingle(comptime StructType: type, comptime statement: []const u8, params: anytype) !?StructType {
    if (@typeInfo(StructType) != .Struct) {
        @compileError("querySingle: StructType must be a struct, you may want to use querySingleValue instead");
    }

    const tuplas = try query(StructType, statement, params);
    defer sql_allocator.free(tuplas);

    if (tuplas.len > 1) {
        @panic("querySingle returned more than one tuple\n");
    }

    return if (tuplas.len > 0) tuplas[0] else null;
}

pub fn querySingleValue(comptime Type: type, comptime statement: []const u8, params: anytype) !?Type {
    if (@typeInfo(Type) == .Struct) {
        @compileError("querySingleValue with struct type: use querySingle instead");
    }

    const StructType = struct {
        value: Type,
    };

    const value_struct = (try querySingle(StructType, statement, params)) orelse return null;
    return value_struct.value;
}

pub fn insert(comptime StructType: type, comptime table_name: []const u8, values: []const StructType) !usize {
    var cursor = try connection.getCursor(sql_allocator);
    defer cursor.deinit() catch unreachable;
    return try cursor.insert(StructType, table_name, values);
}

pub fn createSavePoint(comptime nombre: []const u8) !void {
    try execute("SAVEPOINT " ++ nombre, .{});
}

pub fn rollbackToSavePoint(comptime nombre: ?[]const u8) !void {
    if (nombre) |s| {
        try execute("ROLLBACK TO " ++ s, .{});
    } else {
        try execute("ROLLBACK", .{});
    }
}

pub fn commit() !void {
    try execute("COMMIT", .{});
}
