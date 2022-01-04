const std = @import("std");
const sql = @import("sql.zig");
const utils = @import("utils.zig");
const consts = @import("consts.zig");
const print = utils.print;

const stdin = std.io.getStdIn().reader();

const global_allocator = std.heap.page_allocator;

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

const Contrato = struct {
    id_contrato: u32,
    cuenta_bancaria: []const u8,
    cantidad_pagada: u32,
    fecha_caducidad: sql.SqlDate,
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

    // DANI:
    // const file_contents = try utils.readFile(archivo, global_allocator);
    // defer global_allocator.free(file_contents);

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

    // DANI: este check mejor lo metes dentro del sql en ELIMINAR_CANCION y que haga
    // raise_application_error para que nos llegue aquí el mensaje de error en sql_err.msg
    // SOY DANI: YA LO HE HECHO :)
    // const check = (try sql.querySingleValue(u32, "SELECT id_cancion FROM cancion_sube WHERE id_cancion=?;", .{id}));
    // if (check == 0) {
    //     print("Error: canción no encontrada\n", .{});
    //     return;
    // }

    sql.execute("BEGIN ELIMINAR_CANCION(?); END;", .{id}) catch |err| {
        const sql_err = sql.getLastError() orelse return err;
        defer sql_err.deinit();
        print("Error borrando canción: {s}\n", .{sql_err.msg});
        return;
    };

    try sql.commit();

    print("Canción eliminada con éxito\n", .{});
}

fn listarCancionesAutor(autor: []const u8) !void {
    var lista = try sql.query(Cancion_Sube,
        \\ SELECT * FROM(
        \\  SELECT * FROM cancion_sube WHERE id_cancion IN (SELECT * FROM cancion_promocionada)
        \\  UNION
        \\  SELECT * FROM cancion_sube WHERE id_cancion IN (SELECT * FROM cancion_activa)
        \\ )
        \\ WHERE nick = ?; 
    , .{autor});
    defer sql.getAllocator().free(lista);

    for (lista) |fila| {
        print("{d}. {s} - {s}\n", .{ fila.id_cancion, fila.titulo, fila.nick });
    }
}

fn listarCanciones() !void {
    var lista = try sql.query(Cancion_Sube,
        \\ SELECT * FROM(
        \\  SELECT * FROM cancion_sube WHERE id_cancion IN (SELECT * FROM cancion_promocionada)
        \\  UNION
        \\  SELECT * FROM cancion_sube WHERE id_cancion IN (SELECT * FROM cancion_activa)
        \\ )
    , .{});
    defer sql.getAllocator().free(lista);

    for (lista) |fila| {
        print("{d}. {s} - {s}\n", .{ fila.id_cancion, fila.titulo, fila.nick });
    }
}

fn menuMiCuenta(nick: []const u8) !void {}

fn menuMisCanciones(nick: []const u8) !void {
    while (true) {
        print("\n1. Subir Canción\n2. Eliminar Canción\n3. Listar Canciones\n4. Salir", .{});
        const input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => try subirCancion(nick),
            2 => try eliminarCancion(),
            3 => try listarCancionesAutor(nick),
            4 => break,
            else => unreachable,
        }
    }
}

fn menuMisContratos(nick: []const u8) !void {
    while (true) {
        print("\n[MIS CONTRATOS]\n", .{});
        try listarContratos(nick);
        print("\n1. Crear contrato de autor\n2. Crear contrato de promoción\n3. Renovar contrato\n4. Atrás\n", .{});
        const input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => try crearContratoAutor(),
            2 => try crearContratoPromocion(),
            3 => try renovarContrato(),
            4 => break,
            else => {},
        }
    }
}

fn listarContratos(nick: []const u8) !void {
    const contratos_autor = try sql.query(
        Contrato,
        "SELECT DISTINCT id_contrato FROM contrato_autor NATURAL JOIN firma NATURAL JOIN cancion_sube WHERE nick = ?",
        .{nick},
    );
    defer sql.getAllocator().free(contratos_autor);

    for (contratos_autor) |autor| {
        print("Contrato de autor {d}\n", .{
            autor.id_contrato,
        });
    }

    const contratos_promo = try sql.query(
        Contrato,
        "SELECT DISTINCT id_contrato, fecha_caducidad FROM contrato_promocion NATURAL JOIN firma NATURAL JOIN cancion_sube WHERE nick = ?",
        .{nick},
    );
    defer sql.getAllocator().free(contratos_promo);

    for (contratos_promo) |promo| {
        print("Contrato de promoción {d}, fecha de caducidad: {}\n", .{
            promo.id_contrato,
            utils.fmtSqlDate(promo.fecha_caducidad),
        });
    }
}

fn crearContratoAutor() !void {
    print("\nIntroduce cuenta bancaria en la que abonar:\n", .{});
    var buf_cuenta_banco: [consts.max_length.cuenta_banco]u8 = undefined;
    const cuenta_banco = try utils.readString(stdin, &buf_cuenta_banco);

    print("\nIntroduce la cantidad a pagar:\n", .{});
    const cantidad_pagar = try utils.readNumber(u32, stdin);

    try sql.execute("BEGIN crear_contrato_autor(?, ?); END;", .{
        cuenta_banco,
        cantidad_pagar,
    });
    try sql.commit();
    print("\nContrato de autor creado!\n", .{});
}

fn crearContratoPromocion() !void {
    print("\nIntroduce cuenta bancaria en la que abonar:\n", .{});
    var buf_cuenta_banco: [consts.max_length.cuenta_banco]u8 = undefined;
    const cuenta_banco = try utils.readString(stdin, &buf_cuenta_banco);

    print("\nIntroduce la cantidad a pagar:\n", .{});
    const cantidad_pagar = try utils.readNumber(u32, stdin);

    print("Introduce la fecha de vencimiento del contrato (dia): \n", .{});
    const day = try utils.readNumber(u8, stdin);
    print("Introduce la fecha de vencimiento del contrato (mes): \n", .{});
    const month = try utils.readNumber(u8, stdin);
    print("Introduce la fecha de vencimiento del contrato (año): \n", .{});
    const year = try utils.readNumber(i16, stdin);
    const fecha_vencimiento = sql.SqlDate{
        .day = day,
        .month = month,
        .year = year,
    };

    try sql.execute("BEGIN crear_contrato_promocion(?, ?); END;", .{ cuenta_banco, cantidad_pagar, fecha_vencimiento });
    try sql.commit();
    print("contrato de promocion creado!\n", .{});
}

fn renovarContrato() !void {
    print("\nIntroduce el indentificador del contrato que desea renovar:\n", .{});
    const id_cont = try utils.readNumber(u32, stdin);

    print("Introduce la fecha de renovación del contrato (dia): \n", .{});
    const day = try utils.readNumber(u8, stdin);
    print("Introduce la fecha de renovación del contrato (mes): \n", .{});
    const month = try utils.readNumber(u8, stdin);
    print("Introduce la fecha de renovación del contrato (año): \n", .{});
    const year = try utils.readNumber(i16, stdin);
    const fecha_renovacion = sql.SqlDate{
        .day = day,
        .month = month,
        .year = year,
    };

    try sql.execute("BEGIN renovar_contrato(?, ?); END;", .{ id_cont, fecha_renovacion });
    try sql.commit();
    print("contrato renovado!\n", .{});
}

fn menuMisPlaylists(nick: []const u8) !void {
    while (true) {
        print("\n[MIS PLAYLISTS]\n", .{});
        try listarPlaylistsAutor(nick);
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

fn listarPlaylistsAutor(nick: []const u8) !void {
    const playlists = try sql.query(
        Playlist,
        "SELECT * FROM playlists_crea WHERE nick = ?",
        .{nick},
    );
    defer sql.getAllocator().free(playlists);

    for (playlists) |playlist| {
        print("{d}: {s}, creada el {}\n", .{
            playlist.id_playlist,
            playlist.nombre,
            utils.fmtSqlDate(playlist.fecha_creacion),
        });
    }
}

// TODO: Comprobar que es publica
fn listarPlaylists() !void {
    const playlists = try sql.query(
        Playlist,
        "SELECT * FROM playlists_crea",
        .{},
    );
    defer sql.getAllocator().free(playlists);

    for (playlists) |playlist| {
        print("{d}: {s}, creada el {}\n", .{
            playlist.id_playlist,
            playlist.nombre,
            utils.fmtSqlDate(playlist.fecha_creacion),
        });
    }
}
fn crearPlaylist(nick: []const u8) !void {
    print("\nIntroduce nombre de la playlist:\n", .{});
    var buf_nombre_playlist: [consts.max_length.nombre_playlist]u8 = undefined;
    const nombre_playlist = try utils.readString(stdin, &buf_nombre_playlist);

    print("Quieres que sea una playlist privada? (y/n)\n", .{});
    const privada = try utils.readBoolYN(stdin);

    try sql.execute("BEGIN crear_playlist(?, ?, ?); END;", .{
        nombre_playlist,
        nick,
        @intCast(u32, @boolToInt(privada)),
    });
    try sql.commit();
    print("playlist creada!\n", .{});
}

fn eliminarPlaylist(nick: []const u8) !void {
    print("\nIntroduce el id de la playlist a eliminar:\n", .{});
    const id_playlist = try utils.readNumber(u32, stdin);
    sql.execute("BEGIN eliminar_playlist(?, ?); END;", .{ id_playlist, nick }) catch |err| {
        const sql_err = sql.getLastError() orelse return err;
        defer sql_err.deinit();
        print("Error eliminando playlist: {s}\n", .{sql_err.msg});
        return;
    };
    try sql.commit();
    print("Playlist eliminada!\n", .{});
}

fn modificarPlaylist(nick: []const u8) !void {
    print("\nIntroduce el id de la playlist a modificar:\n", .{});
    const id_playlist = try utils.readNumber(u32, stdin);

    // Comprobar que es del usuario
    const count = try sql.querySingleValue(
        u32,
        "SELECT COUNT(*) FROM playlists_crea WHERE nick = ? AND id_playlist = ?;",
        .{ nick, id_playlist },
    );
    if (count.? == 0) {
        print("Id inválido\n", .{});
        return;
    }

    // ESTE MENÚ ES DE MIGUEL
    while (true) {
        try listarCancionesPlaylist(id_playlist);
        print("\n1. Añadir canción\n2. Eliminar canción\n3. Atrás\n", .{});
        const input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => {},
            2 => {},
            3 => break,
            else => {},
        }
    }
}

fn menuCancion(id_cancion: u32) !void {
    var cancion = try sql.query(Cancion_Sube, "SELECT * FROM CANCION_SUBE WHERE id_cancion=?", .{id_cancion});
    defer sql.getAllocator().free(cancion);

    print("id: {d}\ntitulo: {s}\narchivo: {s}\nfecha: {}\netiqueta: {s}\nnick: {s}", .{ cancion.id_cancion, cancion.titulo, cancion.archivo, cancion.fecha, cancion.etiqueta, cancion.nick });

    while (true) {
        print("\n1. Reproducir\n2. Añadir a playlist\n3. Evaluar\n4. Atrás\n", .{});
        const input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => try reproducir(id_cancion),
            2 => try anadirAPlaylist(id_cancion),
            3 => try evaluar(id_cancion),
            4 => break,
            else => {},
        }
    }
}

fn reproducir(id_cancion: u32) !void {}

fn anadirAPlaylist(id_cancion: u32) !void {}

fn evaluar(id_cancion: u32) !void {
    print("\nIntroduce la evaluación de la canción:\n", .{});
    const eval = try utils.readNumber(u32, stdin);

    var eval_actual = try sql.query(Cancion_Sube, "SELECT evaluacion FROM CANCION_SUBE WHERE id_cancion=?", .{id_cancion});
    defer sql.getAllocator().free(eval_actual);

    var aux = try sql.query(Cancion_Sube, "UPDATE CANCION_SUBE SET evaluacion = ? WHERE id_cancion=?", .{ eval, id_cancion });
    defer sql.getAllocator().free(aux);
}

fn accederPerfil() !void {
    print("Introduce un nickname:\n", .{});
    var buf_nick: [consts.max_length.nick]u8 = undefined;
    const nickname = try utils.readString(stdin, &buf_nick);

    const user = (try sql.querySingle(Usuario, "SELECT * FROM usuario WHERE nick=?;", .{nickname})) orelse {
        print("Error: usuario no encontrado\n", .{});
        return;
    };

    print("=== CANCIONES ===\n", .{});
    try listarCancionesAutor(nickname);
    print("\n=== PLAYLISTS ===\n", .{});
    try listarPlaylistsAutor(nickname);
}

// TODO
fn listarCancionesPlaylist(id_playlist: usize) !void {}

fn accederCancion() !void {
    // TODO pensar cómo hacer que solo muestre opciones 2 y 3 si es autor. igual que
    // la funcion login devuelva un Usuario con toda la información?
    while (true) {
        print("Introduce el id de la canción.", .{});
        const input = try utils.readNumber(u32, stdin);
        const id_cancion = (try sql.querySingleValue(u32, "SELECT * FROM cancion_activa WHERE id_cancion=?;", .{input})) orelse {
            print("Error: canción no encontrada\n", .{});
            return;
        };

        print("AQUI VA EL MENU DE CANCION DE LA CANCION {d}\n", .{id_cancion});
        break;
    }
}

fn accederPlaylists() !void {
    print("Introduce el id de la playlist.", .{});
    const input = try utils.readNumber(u32, stdin);
    const id_playlist = (try sql.querySingleValue(u32, "SELECT * FROM playlist_publica WHERE id_playlist=?;", .{input})) orelse {
        print("Error: playlist no encontrada\n", .{});
        return;
    };

    var lista = try sql.query(Cancion_Sube,
        \\SELECT * FROM playlist_publica WHERE id_playlist = ?
    , .{input});
    defer sql.getAllocator().free(lista);

    for (lista) |fila| {
        print("{d}. {s} - {s}\n", .{ fila.id_cancion, fila.titulo, fila.nick });
    }
}

fn menuExplorar(nick: []const u8) !void {
    while (true) {
        print("\n1. Buscar canciones\n2. Buscar playlists\n3. Acceder a canción\n4. Acceder perfil\n5. Acceder a playlist\n6. Salir\n", .{});
        const input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => try listarCanciones(),
            2 => try listarPlaylists(),
            3 => try accederCancion(),
            4 => try accederPerfil(),
            5 => try accederPlaylists(),
            6 => break,
            else => {},
        }
    }
}

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
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = &gpa.allocator;
    // defer _ = gpa.deinit();

    try sql.init(global_allocator);
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
