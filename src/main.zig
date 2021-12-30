const std = @import("std");
const sql = @import("sql.zig");
const utils = @import("utils.zig");
const consts = @import("consts.zig");
const print = utils.print;

const stdin = std.io.getStdIn().reader();

fn getFechaActual() sql.SqlDate {
    return bloque: {
        const date = utils.DateTime.fromTimestamp(std.time.timestamp());
        break :bloque sql.SqlDate{
            .year = @intCast(c_short, date.year),
            .month = date.month,
            .day = date.day,
        };
    };
}

fn login(buf_nickname: *[consts.max_length.nick]u8) !?[]const u8 {
    var buf_password: [consts.max_length.contrasena]u8 = undefined;

    print("Introduce tu nickname:\n", .{});
    const nickname = try utils.readString(stdin, buf_nickname);
    print("Introduce tu contraseña:\n", .{});
    const password = try utils.readString(stdin, &buf_password);

    const check = (try sql.querySingleValue(u32, "SELECT check_user(?, ?) FROM dual;", .{ nickname, password })).?;
    if (check == 0) {
        print("Error: cuenta inválida\n", .{});
        return null;
    }

    return nickname;
}

const Usuario = struct {
    nick: []const u8,
    nombre: []const u8,
    apellidos: []const u8,
    correo: []const u8,
    contrasena: []const u8,
    fecha_nacimiento: sql.SqlDate,
};

const Cancion_Sube = struct { id_cancion: u32, titulo: []const u8, archivo: sql.SqlBlob, fecha: sql.SqlDate, duracion: u32, etiqueta: []const u8 };

fn register() !void {
    var buf_nick: [consts.max_length.nick]u8 = undefined;
    var buf_nombre: [consts.max_length.nombre]u8 = undefined;
    var buf_apellidos: [consts.max_length.apellidos]u8 = undefined;
    var buf_correo: [consts.max_length.correo]u8 = undefined;
    var buf_contrasena: [consts.max_length.contrasena]u8 = undefined;

    print("Introduce tu nickname:\n", .{});
    const nick = try utils.readString(stdin, &buf_nick);
    print("Introduce tu nombre sin apellidos:\n", .{});
    const nombre = try utils.readString(stdin, &buf_nombre);
    print("Introduce tus apellidos:\n", .{});
    const apellidos = try utils.readString(stdin, &buf_apellidos);
    print("Introduce tu correo:\n", .{});
    const correo = try utils.readString(stdin, &buf_correo);
    print("Introduce tu contraseña:\n", .{});
    const contrasena = try utils.readString(stdin, &buf_contrasena);
    print("Introduce tu fecha de nacimiento (dia): \n", .{});
    const day = try utils.readNumber(u8, stdin);
    print("Introduce tu fecha de nacimiento (mes): \n", .{});
    const month = try utils.readNumber(u8, stdin);
    print("Introduce tu fecha de nacimiento (año): \n", .{});
    const year = try utils.readNumber(i16, stdin);
    const fecha_nacimiento = sql.SqlDate{
        .day = day,
        .month = month,
        .year = year,
    };

    sql.execute("BEGIN REGISTRAR_USUARIO(?, ?, ?, ?, ?, ?); END;", .{
        nick,
        nombre,
        apellidos,
        correo,
        contrasena,
        fecha_nacimiento,
    }) catch |err| if (err == error.Error) {
        const sql_err = sql.getLastError();
        defer sql_err.deinit();
        print("Error creando usuario: {s}\n", .{sql_err.msg});
        return;
    } else return err;

    try sql.commit();

    print("Usuario creado con éxito!\n", .{});
}

fn subirCancion() !void {
    var buf_id: u32 = undefined;
    var buf_titulo: [consts.max_length.nombre]u8 = undefined;
    var buf_archivo: [consts.max_length.nombre]u8 = undefined;
    var buf_fecha: sql.SqlDate = undefined;
    var buf_duracion: u32 = undefined;
    var buf_etiqueta: [consts.max_length.nombre]u8 = undefined;

    print("Introduce el título:\n", .{});
    const titulo = try utils.readString(stdin, &buf_titulo);
    print("Introduce la ruta al archivo:\n", .{});
    const archivo = try utils.readString(stdin, &buf_archivo);
    print("Introduce una etiqueta:\n", .{});
    const etiqueta = try utils.readString(stdin, &buf_etiqueta);
    const fecha = getFechaActual();

    // Calculamos id
    const id_cancion = bloque: {
        const max_cid = (try sql.querySingleValue(u32,
            \\ SELECT MAX(id_cancion)
            \\ FROM cancion_sube;
        , .{})) orelse 0;
        break :bloque max_cid + 1;
    };

    // sql.execute("BEGIN SUBIR_CANCION(?, ?, ?, ?, ?, ?); END;", .{
    //     id_cancion,
    //     titulo,
    //     sql.SqlNull,
    //     fecha,
    //     sql.SqlNull,
    //     etiqueta,
    // }) catch |err| if (err == error.Error) {
    //     const sql_err = sql.getLastError();
    //     defer sql_err.deinit();
    //     print("Error creando usuario: {s}\n", .{sql_err.msg});
    //     return;
    // } else return err;

    // try sql.commit();

    print("FALTA HACER LA COSA DE LOS BLOB!!!\n", .{});
}

fn eliminarCancion() !void {
    var buf_id: u32 = undefined;

    print("Introduce el id:\n", .{});
    const id = try utils.readNumber(stdin, &buf_id);

    const check = (try sql.querySingleValue(u32, "SELECT id_cancion FROM cancion_sube WHERE id_cancion=?;", .{id})).?;
    if (check == 0) {
        print("Error: canción no encontrada\n", .{});
        return null;
    }

    sql.execute("BEGIN ELIMINAR_CANCION(?); END;", .{id}) catch |err| if (err == error.Error) {
        const sql_err = sql.getLastError();
        defer sql_err.deinit();
        print("Error borrando canción: {s}\n", .{sql_err.msg});
        return;
    } else return err;

    try sql.commit();

    print("Canción eliminada con éxito\n", .{});
}
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;

    try sql.init(allocator);
    defer sql.deinit();

    // Run mainApp. If a SQL error occurs, get and print the error message for debugging.
    mainApp() catch |err| switch (err) {
        error.Error => {
            const sql_err = sql.getLastError();
            defer sql_err.deinit();
            print("[SQL ERROR {s}]: {s}\n", .{ sql_err.sql_state, sql_err.msg });
            return err;
        },
        else => return err,
    };
}

pub fn mainApp() !void {
    print("Bienvenido a SpotyCloud!\n", .{});

    var nickname_buf: [consts.max_length.nick]u8 = undefined;
    var nickname: []const u8 = undefined;

    while (true) {
        print("\n1. Logearse\n2. Registrarse\n", .{});
        var input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => {
                nickname = (try login(&nickname_buf)) orelse continue;
                while (true) {
                    print("\n1. Subir Canción\n2. Eliminar Canción\n", .{});
                    input = try utils.readNumber(usize, stdin);
                    switch (input) {
                        1 => try subirCancion(),
                        else => unreachable,
                    }
                }
                break;
            },
            2 => try register(),

            else => unreachable,
        }
    }

    print("\nBienvenido {s}!\n", .{nickname});
}
