const std = @import("std");
const sql = @import("sql.zig");
const utils = @import("utils.zig");
const consts = @import("consts.zig");
const print = utils.print;

const stdin = std.io.getStdIn().reader();

fn login() !void {
    var buf_nickname: [consts.max_length.nick]u8 = undefined;
    var buf_password: [consts.max_length.contrasena]u8 = undefined;

    print("Introduce tu nickname:\n", .{});
    const nickname = try utils.readString(stdin, &buf_nickname);
    print("Introduce tu contraseña:\n", .{});
    const password = try utils.readString(stdin, &buf_password);

    var password_hash: [utils.md5_hex_length]u8 = undefined;
    utils.md5(password, &password_hash);

    // TODO Enviar query a la base de datos, devolver usuario
}

const Usuario = struct {
    nick: []const u8,
    nombre: []const u8,
    apellidos: []const u8,
    correo: []const u8,
    contrasena: []const u8,
    fecha_nacimiento: sql.SqlDate,
};

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
    print("Introduce tu fecha de nacimiento: (TODO)\n", .{});
    // const fecha = utils.DateTime.fromTimestamp(0);
    const fecha = sql.SqlDate{
        .day = 1,
        .month = 1,
        .year = 2000,
    };

    const usuario = Usuario{
        .nick = nick,
        .nombre = nombre,
        .apellidos = correo,
        .correo = correo,
        .contrasena = contrasena,
        .fecha_nacimiento = fecha,
    };

    // Ejemplo de handleo de errores desde zig, aunque lo ideal es que la función
    // de SQL devuelva ya un mensaje de error y aquí simplemente se imprima sql_err.msg
    _ = sql.insert(Usuario, "usuario", &.{usuario}) catch |err| if (err == error.Error) {
        const sql_err = sql.getLastError();
        defer sql_err.deinit();
        switch (sql_err.sql_state) {
            .IntegrityConstraintViolation => {
                print("Ya existe un usuario con ese nick o correo\n", .{});
                return;
            },
            else => return err,
        }
    } else return err;

    try sql.commit();

    print("Usuario creado con éxito!\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;

    try sql.init(allocator);
    defer sql.deinit();

    // Run mainApp. If a SQL error occurs, get and print the error message.
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
    print("1. Logearse\n2. Registrarse\n", .{});

    const input = try utils.readNumber(usize, stdin);
    switch (input) {
        1 => try login(),
        2 => try register(),
        else => unreachable,
    }
}
