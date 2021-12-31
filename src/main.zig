const std = @import("std");
const sql = @import("sql.zig");
const utils = @import("utils.zig");
const consts = @import("consts.zig");
const print = utils.print;

const stdin = std.io.getStdIn().reader();

// TODO separar en varios archivos?

const Usuario = struct {
    nick: []const u8,
    nombre: []const u8,
    apellidos: []const u8,
    correo: []const u8,
    contrasena: []const u8,
    fecha_nacimiento: sql.SqlDate,
};

const Cancion_Sube = struct {
    id_cancion: u32,
    titulo: []const u8,
    archivo: []const u8,
    fecha: sql.SqlDate,
    etiqueta: []const u8,
    nick: []const u8,
};

const Playlist = struct {
    id_playlist: u32,
    nombre: []const u8,
    fecha_creacion: sql.SqlDate,
    nick: []const u8,
};

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

/// Pide nickname y contraseña, guardando el nickname en `buf_nickname`.
/// Devuelve una slice apuntando a `buf_nickname` con el nick leído, o null
/// si el login ha sido incorrecto.
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

/// Pide los datos y registra un usuario
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
    }) catch |err| {
        const sql_err = sql.getLastError() orelse return err;
        defer sql_err.deinit();
        print("Error creando usuario: {s}\n", .{sql_err.msg});
        return;
    };

    try sql.commit();

    print("Usuario creado con éxito!\n", .{});
}

fn subirCancion(nick: []const u8) !void {
    var buf_id: u32 = undefined;
    var buf_titulo: [consts.max_length.nombre]u8 = undefined;
    var buf_archivo: [consts.max_length.nombre]u8 = undefined;
    var buf_fecha: sql.SqlDate = undefined;
    var buf_duracion: u32 = undefined;
    var buf_etiqueta: [consts.max_length.nombre]u8 = undefined;

    print("Introduce el título:\n", .{});
    const titulo = try utils.readString(stdin, &buf_titulo);
    print("Introduce la ruta al archivo:\n", .{});

    // TODO: ARREGLAR PARA QUE SE LE PASE BIEN EL ARCHIVO Y CALCULAR DURACION
    const archivo = "f";
    const duracion = 69;
    // --------------------------------------

    print("Introduce una etiqueta:\n", .{});
    const etiqueta = try utils.readString(stdin, &buf_etiqueta);
    const fecha = getFechaActual();

    sql.execute("BEGIN SUBIR_CANCION(?, ?, ?, ?, ?); END;", .{ titulo, archivo, duracion, etiqueta, nick }) catch |err| {
        const sql_err = sql.getLastError() orelse return err;
        defer sql_err.deinit();
        print("Error subiendo canción: {s}\n", .{sql_err.msg});
        return;
    };

    try sql.commit();

    print("Canción subida con éxito (FALTA HACER LO DEL BLOB)!\n", .{});
}

fn eliminarCancion() !void {
    print("Introduce el id:\n", .{});
    const id = try utils.readNumber(u8, stdin);

    const check = (try sql.querySingleValue(u32, "SELECT id_cancion FROM cancion_sube WHERE id_cancion=?;", .{id})).?;
    if (check == 0) {
        print("Error: canción no encontrada\n", .{});
        return;
    }

    sql.execute("BEGIN ELIMINAR_CANCION(?); END;", .{id}) catch |err| {
        const sql_err = sql.getLastError() orelse return err;
        defer sql_err.deinit();
        print("Error borrando canción: {s}\n", .{sql_err.msg});
        return;
    };

    try sql.commit();

    print("Canción eliminada con éxito\n", .{});
}

fn listarCanciones(buf_nick: []const u8) !void {
    var lista = try sql.query(Cancion_Sube, "SELECT * FROM CANCION_SUBE WHERE id_cancion IN (SELECT * FROM cancion_activa) AND nick=?", .{buf_nick});

    for (lista) |fila| {
        print("id: {d}, titulo: {s}", .{ fila.id_cancion, fila.titulo });
    }
}

fn menuMiCuenta(nick: []const u8) !void {}

fn menuMisCanciones(nick: []const u8) !void {
    while (true) {
        print("\n1. Subir Canción\n2. Eliminar Canción\n3. Listar Canciones", .{});
        const input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => try subirCancion(nick),
            2 => try eliminarCancion(),
            3 => try listarCanciones(nick),
            else => unreachable,
        }
    }
}

fn menuMisContratos(nick: []const u8) !void {}

fn menuMisPlaylists(nick: []const u8) !void {
    while (true) {
        try listarPlaylists(nick);
        print("\n1. Crear playlist\n2. Eliminar playlist\n3. Modificar playlist\n4. Atrás\n", .{});
        const input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => try crearPlaylist(nick),
            2 => try eliminarPlaylist(nick),
            3 => try modificarPlaylist(nick),
            4 => break,
            else => {},
        }
    }
}

fn listarPlaylists(nick: []const u8) !void {}

fn crearPlaylist(nick: []const u8) !void {
    // TODO no se por que si metes una cadena de longitud mas de 8 se guarda como ¿¿¿¿¿¿¿¿
    print("\nIntroduce nombre de la playlist:\n", .{});
    var buf_nombre_playlist: [consts.max_length.nombre_playlist]u8 = undefined;
    const nombre_playlist = try utils.readString(stdin, &buf_nombre_playlist);
    try sql.execute("BEGIN crear_playlist(?, ?); END;", .{
        nombre_playlist,
        nick,
    });
    try sql.commit();
    print("playlist creada!\n", .{});
}

fn eliminarPlaylist(nick: []const u8) !void {}

fn modificarPlaylist(nick: []const u8) !void {}

fn menuExplorar(nick: []const u8) !void {}

fn menuPrincipal(nick: []const u8) !void {
    // TODO pensar cómo hacer que solo muestre opciones 2 y 3 si es autor. igual que
    // la funcion login devuelva un Usuario con toda la información?
    while (true) {
        print("\n1. Mi cuenta\n2. Mis canciones\n3. Mis contratos\n4. Mis playlists.\n5. Explorar\n6. Salir\n", .{});
        const input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => try menuMiCuenta(nick),
            2 => try menuMisCanciones(nick),
            3 => try menuMisContratos(nick),
            4 => try menuMisPlaylists(nick),
            5 => try menuExplorar(nick),
            6 => break,
            else => {},
        }
    }
}

pub fn mainApp() !void {
    print("Bienvenido a SpotyCloud!\n", .{});

    var nickname_buf: [consts.max_length.nick]u8 = undefined;
    var nickname: []const u8 = undefined;

    while (true) {
        print("\n1. Logearse\n2. Registrarse\n", .{});
        const input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => {
                nickname = (try login(&nickname_buf)) orelse continue;
                break;
            },
            2 => try register(),
            else => {},
        }
    }

    print("\nBienvenido {s}!\n", .{nickname});
    try menuPrincipal(nickname);
    print("\nHasta luego {s}!\n", .{nickname});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;

    try sql.init(allocator);
    defer sql.deinit();

    // Run mainApp. If a SQL error occurs, get and print the error message for debugging.
    mainApp() catch |err| switch (err) {
        error.Error => {
            const sql_err = sql.getLastError() orelse {
                print("SQL ERROR without error message\n", .{});
                return err;
            };
            defer sql_err.deinit();
            print("[SQL ERROR {s}]: {s}\n", .{ sql_err.sql_state, sql_err.msg });
            return err;
        },
        else => return err,
    };
}
