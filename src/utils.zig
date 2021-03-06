const std = @import("std");
const sql = @import("sql.zig");
const Allocator = std.mem.Allocator;

pub fn print(comptime format: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print(format, args) catch unreachable;
}

/// Lee una string de `in`, guardándola en `buf` y devolviendo una slice que
/// apunta a `buf` con la longitud de la cadena leída
pub fn readString(in: std.fs.File.Reader, buf: []u8) ![]u8 {
    while (true) {
        print("> ", .{});
        const maybe_result = in.readUntilDelimiterOrEof(buf, '\n') catch |err| switch (err) {
            // Si el usuario introdujo una entrada demasiado larga (no cabe en buf),
            // volver a intentarlo
            error.StreamTooLong => {
                print("Entrada demasiado larga!\n", .{});
                try in.skipUntilDelimiterOrEof('\n');
                continue;
            },
            else => return err,
        };
        return (maybe_result orelse error.EndOfFile);
    }
}

pub fn readNumber(comptime T: type, in: std.fs.File.Reader) !T {
    var buf: [10]u8 = undefined;
    while (true) {
        // Leer entrada
        const input = try readString(in, &buf);

        // Parsear la entrada como un entero de tipo `T`
        const result = std.fmt.parseInt(T, input, 0) catch {
            print("Debes introducir un número\n\n", .{});
            continue;
        };
        return result;
    }
}

pub fn readBoolYN(in: std.fs.File.Reader) !bool {
    var buf: [1]u8 = undefined;
    _ = try readString(in, &buf);
    return buf[0] == 'y';
}

/// Caller owns memory and must free it with allocator.free.
pub fn readFile(allocator: *Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{ .read = true });
    defer file.close();
    const size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, size);
    const bytes_read = try file.readAll(buffer);
    std.debug.assert(bytes_read == size);
    return buffer;
}

/// Returns URL to uploaded file. Caller owns returned memory and must free
/// it with allocator.free.
pub fn uploadFile(allocator: *Allocator, path: []const u8) ![]u8 {
    // Somos unos vagos asi que ejecutamos curl y que lo haga él todo
    try std.fs.cwd().access(path, .{ .read = true });

    const param = try std.fmt.allocPrint(allocator, "files[]=@{s}", .{path});
    defer allocator.free(param);

    var process = try std.ChildProcess.init(&.{
        "curl",
        "--silent",
        "--output",
        "/dev/null",
        "-F",
        param,
        "https://mailboxdrive.com/php/upload.php",
    }, allocator);
    defer process.deinit();

    const exit_status = try process.spawnAndWait();
    switch (exit_status) {
        .Exited => |code| {
            if (code != 0) {
                std.log.warn("curl finished with code {}\n", .{code});
                return error.CurlFailed;
            }
        },
        else => unreachable,
    }

    const file_name = std.fs.path.basename(path);
    const file_name_escaped = try escapeString(allocator, file_name);
    defer allocator.free(file_name_escaped);

    const url = try std.fmt.allocPrint(
        allocator,
        "https://www.mboxdrive.com/{s}",
        .{file_name_escaped},
    );
    return url;
}

/// Downloads file from `url` and places it at `output_path`.
pub fn downloadFile(allocator: *Allocator, url: []const u8, output_path: []const u8) !void {
    // Somos unos vagos asi que ejecutamos curl y que lo haga él todo
    var process = try std.ChildProcess.init(&.{
        "curl",
        // "--silent",
        "--no-progress-meter",
        "--output",
        output_path,
        url,
    }, allocator);
    defer process.deinit();

    const exit_status = try process.spawnAndWait();
    switch (exit_status) {
        .Exited => |code| {
            if (code != 0) {
                std.log.warn("curl finished with code {}\n", .{code});
                return error.CurlFailed;
            }
        },
        else => unreachable,
    }
}

/// unreserved  = ALPHA / DIGIT / "-" / "." / "_" / "~"
fn isUnreserved(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '-', '.', '_', '~' => true,
        else => false,
    };
}

/// Applies URI encoding and replaces all reserved characters with their respective %XX code.
// https://github.com/MasterQ32/zig-uri/blob/master/uri.zig
pub fn escapeString(allocator: *Allocator, input: []const u8) error{OutOfMemory}![]const u8 {
    var outsize: usize = 0;
    for (input) |c| {
        outsize += if (isUnreserved(c)) @as(usize, 1) else 3;
    }
    var output = try allocator.alloc(u8, outsize);
    var outptr: usize = 0;

    for (input) |c| {
        if (isUnreserved(c)) {
            output[outptr] = c;
            outptr += 1;
        } else {
            var buf: [2]u8 = undefined;
            _ = std.fmt.bufPrint(&buf, "{X:0>2}", .{c}) catch unreachable;

            output[outptr + 0] = '%';
            output[outptr + 1] = buf[0];
            output[outptr + 2] = buf[1];
            outptr += 3;
        }
    }
    return output;
}

pub fn fmtSqlDate(date: sql.SqlDate) std.fmt.Formatter(fmtSqlDateFn) {
    // Devuelve un objeto que al intentar imprimirse llamará a fmtSqlDateFn
    return .{ .data = date };
}

fn fmtSqlDateFn(
    date: sql.SqlDate,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    try writer.print("{}/{}/{}", .{ date.day, date.month, date.year });
}

pub const DateTime = struct {
    day: u8,
    month: u8,
    year: u16,
    hour: u8,
    minute: u8,
    second: u8,

    pub fn fromTimestamp(timestamp: i64) DateTime {
        // aus https://de.wikipedia.org/wiki/Unixzeit
        const unixtime = @intCast(u64, timestamp);
        const SEKUNDEN_PRO_TAG = 86400; //*  24* 60 * 60 */
        const TAGE_IM_GEMEINJAHR = 365; //* kein Schaltjahr */
        const TAGE_IN_4_JAHREN = 1461; //*   4*365 +   1 */
        const TAGE_IN_100_JAHREN = 36524; //* 100*365 +  25 - 1 */
        const TAGE_IN_400_JAHREN = 146097; //* 400*365 + 100 - 4 + 1 */
        const TAGN_AD_1970_01_01 = 719468; //* Tagnummer bezogen auf den 1. Maerz des Jahres "Null" */

        var tagN: u64 = TAGN_AD_1970_01_01 + unixtime / SEKUNDEN_PRO_TAG;
        var sekunden_seit_Mitternacht: u64 = unixtime % SEKUNDEN_PRO_TAG;
        var temp: u64 = 0;

        // Schaltjahrregel des Gregorianischen Kalenders:
        // Jedes durch 100 teilbare Jahr ist kein Schaltjahr, es sei denn, es ist durch 400 teilbar.
        temp = 4 * (tagN + TAGE_IN_100_JAHREN + 1) / TAGE_IN_400_JAHREN - 1;
        var jahr = @intCast(u16, 100 * temp);
        tagN -= TAGE_IN_100_JAHREN * temp + temp / 4;

        // Schaltjahrregel des Julianischen Kalenders:
        // Jedes durch 4 teilbare Jahr ist ein Schaltjahr.
        temp = 4 * (tagN + TAGE_IM_GEMEINJAHR + 1) / TAGE_IN_4_JAHREN - 1;
        jahr += @intCast(u16, temp);
        tagN -= TAGE_IM_GEMEINJAHR * temp + temp / 4;

        // TagN enthaelt jetzt nur noch die Tage des errechneten Jahres bezogen auf den 1. Maerz.
        var monat = @intCast(u8, (5 * tagN + 2) / 153);
        var tag = @intCast(u8, tagN - (@intCast(u64, monat) * 153 + 2) / 5 + 1);
        //  153 = 31+30+31+30+31 Tage fuer die 5 Monate von Maerz bis Juli
        //  153 = 31+30+31+30+31 Tage fuer die 5 Monate von August bis Dezember
        //        31+28          Tage fuer Januar und Februar (siehe unten)
        //  +2: Justierung der Rundung
        //  +1: Der erste Tag im Monat ist 1 (und nicht 0).

        monat += 3; // vom Jahr, das am 1. Maerz beginnt auf unser normales Jahr umrechnen: */
        if (monat > 12) { // Monate 13 und 14 entsprechen 1 (Januar) und 2 (Februar) des naechsten Jahres
            monat -= 12;
            jahr += 1;
        }

        var stunde = @intCast(u8, sekunden_seit_Mitternacht / 3600);
        var minute = @intCast(u8, sekunden_seit_Mitternacht % 3600 / 60);
        var sekunde = @intCast(u8, sekunden_seit_Mitternacht % 60);

        return DateTime{ .day = tag, .month = monat, .year = jahr, .hour = stunde, .minute = minute, .second = sekunde };
    }
};
