const std = @import("std");
const sql = @import("sql.zig");
const utils = @import("utils.zig");
const consts = @import("consts.zig");
const music = @import("music.zig");
const print = utils.print;

const carpeta_musica_path = "music";

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
    archivo_enlace: []const u8,
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
    cantidad_pagada: f32,
    fecha_creacion: sql.SqlDate,
};

const Contrato_Promocion = struct {
    id_contrato: u32,
    cuenta_bancaria: []const u8,
    cantidad_pagada: f32,
    fecha_creacion: sql.SqlDate,
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
fn register(buf_nickname: *[consts.max_length.nick]u8) !?[]const u8 {
    var buf_nombre: [consts.max_length.nombre]u8 = undefined;
    var buf_apellidos: [consts.max_length.apellidos]u8 = undefined;
    var buf_correo: [consts.max_length.correo]u8 = undefined;
    var buf_contrasena: [consts.max_length.contrasena]u8 = undefined;

    print("Introduce tu nickname:\n", .{});
    const nick = try utils.readString(stdin, buf_nickname);
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
        return null;
    };

    try sql.commit();

    print("Usuario creado con éxito!\n", .{});

    return nick;
}

fn subirCancion(nick: []const u8) !void {
    var buf_titulo: [consts.max_length.titulo]u8 = undefined;
    var buf_archivo_ruta: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var buf_etiqueta: [consts.max_length.etiqueta]u8 = undefined;

    print("Introduce el título:\n", .{});
    const titulo = try utils.readString(stdin, &buf_titulo);

    print("Introduce la ruta al archivo:\n", .{});
    const archivo_ruta = try utils.readString(stdin, &buf_archivo_ruta);
    print("Subiendo archivo...\n", .{});
    const archivo_enlace = utils.uploadFile(global_allocator, archivo_ruta) catch |err| {
        print("Ha ocurrido un error subiendo el archivo: {}\n", .{err});
        return;
    };
    defer global_allocator.free(archivo_enlace);

    print("Introduce una etiqueta:\n", .{});
    const etiqueta = try utils.readString(stdin, &buf_etiqueta);

    sql.execute(
        "BEGIN SUBIR_CANCION(?, ?, ?, ?); END;",
        .{ titulo, archivo_enlace, etiqueta, nick },
    ) catch |err| {
        const sql_err = sql.getLastError() orelse return err;
        defer sql_err.deinit();
        print("Error subiendo canción: {s}\n", .{sql_err.msg});
        return;
    };

    try sql.commit();

    print("Canción subida con éxito!\n", .{});
}

fn eliminarCancion(nick: []const u8) !void {
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

    sql.execute("BEGIN ELIMINAR_CANCION(?, ?); END;", .{ id, nick }) catch |err| {
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
    // Selecciona las canciones promocionadas
    // Las une a:
    // Las canciones activas menos las promocionadas (para que se muestren primero las promocionadas y no dos veces)
    //Coge solo las del autor indicado
        \\ SELECT * FROM 
        \\  (SELECT * FROM cancion_promocionada NATURAL JOIN cancion_sube
        \\  UNION
        \\  SELECT * FROM 
        \\      ((SELECT * FROM cancion_activa) MINUS (SELECT * FROM cancion_promocionada)) NATURAL JOIN cancion_sube)
        \\ WHERE nick = ?;
    , .{autor});
    defer sql.getAllocator().free(lista);

    for (lista) |fila| {
        print("{d}. {s} - {s}\n", .{ fila.id_cancion, fila.titulo, fila.nick });
    }
}

fn listarCancionesTitulo() !void {
    var buf_titulo: [consts.max_length.nick]u8 = undefined;

    print("\nIntroduce un título (ninguno buscará todas).", .{});
    const titulo = try utils.readString(stdin, &buf_titulo);

    var lista = try sql.query(Cancion_Sube,
    // Coge las canciones promocionadas
    // Las une a las canciones activas sin promocionar
    // Quita las canciones de autores inactivos
    // A esto aplica las búsquedas
        \\ SELECT * FROM( 
        \\      (
        \\          SELECT * FROM cancion_promocionada NATURAL JOIN cancion_sube 
        \\          UNION
        \\          SELECT * FROM (
        \\              (SELECT * FROM cancion_activa) MINUS (SELECT * FROM cancion_promocionada)
        \\          ) 
        \\          NATURAL JOIN 
        \\          cancion_sube
        \\      )
        \\      MINUS
        \\      (
        \\          SELECT id_cancion, titulo, archivo_enlace, fecha, etiqueta, nick 
        \\          FROM cancion_sube NATURAL JOIN usuario_no_activo
        \\      )
        \\ ) 
        \\ WHERE LOWER(titulo) LIKE '%' || LOWER(?) || '%';
    , .{titulo});
    defer sql.getAllocator().free(lista);

    for (lista) |fila| {
        print("{d}. {s} - {s}\n", .{ fila.id_cancion, fila.titulo, fila.nick });
    }
}

fn addAmigo(nick: []const u8) !void {
    var buf_amigo: [consts.max_length.nick]u8 = undefined;

    print("\nIntroduce el nickname del usuario al que quieres añadir como amigo.", .{});
    const amigo = try utils.readString(stdin, &buf_amigo);

    sql.execute("BEGIN ADD_AMIGO(?, ?); END;", .{ nick, amigo }) catch |err| {
        const sql_err = sql.getLastError() orelse return err;
        defer sql_err.deinit();
        print("Error añadiendo amigo: {s}\n", .{sql_err.msg});
        return;
    };

    try sql.commit();

    print("Ya sois amigos!\n", .{});
}

fn eliminarAmigo(nick: []const u8) !void {
    var buf_migo: [consts.max_length.nick]u8 = undefined;

    print("\nIntroduce el nickname del usuario al que quieres eliminar como amigo.", .{});
    const migo = try utils.readString(stdin, &buf_migo);

    sql.execute("BEGIN ELIMINAR_AMIGO(?, ?); END;", .{ nick, migo }) catch |err| {
        const sql_err = sql.getLastError() orelse return err;
        defer sql_err.deinit();
        print("Error eliminando amigo: {s}\n", .{sql_err.msg});
        return;
    };

    try sql.commit();

    print("Ya no sois amigos\n", .{});
}

fn modificarTipo(nick: []const u8) !void {
    const es_autor = try esAutor(nick);
    const tipo = if (es_autor) "autor" else "usuario";
    const otro_tipo = if (es_autor) "usuario" else "autor";

    print("\nActualmente su tipo es: {s}", .{tipo});
    print("\nVa a cambiar su tipo a: {s}", .{otro_tipo});
    if (es_autor)
        print("\nSi ya ha subido canciones, no puede cambiar a usuario", .{})
    else
        print("\nCuando suba canciones, no podrá revertir el cambio", .{});

    print("\nSeguro que quieres proceder? (y/n)", .{});
    const seguro = try utils.readBoolYN(stdin);

    if (seguro) {
        sql.execute("BEGIN MODIFICAR_TIPO(?, ?); END;", .{ nick, @as(u32, @boolToInt(es_autor)) }) catch |err| {
            const sql_err = sql.getLastError() orelse return err;
            defer sql_err.deinit();
            print("Error modificando tipo: {s}\n", .{sql_err.msg});
            return;
        };

        try sql.commit();

        print("\nSu nuevo tipo es {s}\n", .{otro_tipo});
    }
}

fn darBaja(nick: []const u8) !void {
    print("\nEsto dará de baja su cuenta de forma permanente. Su cuenta, sus canciones y listas no se mostrarán.", .{});
    print("\nSi tiene canciones promocionadas, acabará su promoción.", .{});
    print("\nPara recuperarla, tendrá que contactar con un administrador.", .{});
    print("\nEsta acción hará que salga de la aplicación", .{});

    print("\nSeguro que quieres proceder? (y/n)", .{});
    const seguro = try utils.readBoolYN(stdin);

    if (seguro) {
        sql.execute("BEGIN DESACTIVAR_USUARIO(?); END;", .{nick}) catch |err| {
            const sql_err = sql.getLastError() orelse return err;
            defer sql_err.deinit();
            print("Error modificando tipo: {s}\n", .{sql_err.msg});
            return;
        };

        try sql.commit();

        std.os.exit(0);
    }
}

fn menuMiCuenta(nick: []const u8) !void {
    print("\nMI CUENTA", .{});

    const es_autor = try esAutor(nick);

    const user_data = (try sql.querySingle(Usuario,
        \\ SELECT * FROM USUARIO
        \\  WHERE nick = ?;
    , .{nick})) orelse unreachable;

    print("\nNick: {s}", .{user_data.nick});
    print("\nNombre: {s}", .{user_data.nombre});
    print("\nApellidos: {s}", .{user_data.apellidos});
    print("\nCorreo: {s}", .{user_data.correo});
    print("\nFecha de nacimiento: {}\n", .{utils.fmtSqlDate(user_data.fecha_nacimiento)});

    const tipo = if (es_autor) "Autor" else "Usuario";
    print("\nActualmente su tipo es: {s}\n", .{tipo});

    print("\nLista de amigos:", .{});

    var lista_amigos = try sql.query(Usuario,
    // Coge los usuarios que aparezcan en amistarse en una pareja con el usuario indicado
    // La sintaxis se complica porque no se puede hacer NATURAL JOIN
    // En esta lista aparece el propio usuario, se quita
    // Y quitamos los usuarios inactivos
        \\ ((SELECT NICK, NOMBRE, APELLIDOS, CORREO, CONTRASENA, FECHA_NACIMIENTO
        \\  FROM USUARIO u, (SELECT * FROM AMISTARSE WHERE (nick1 = ? OR nick2 = ?)) am
        \\  WHERE u.nick = am.nick1 OR u.nick = am.nick2)
        \\ MINUS
        \\ (SELECT * FROM USUARIO WHERE nick = ?))
        \\ MINUS
        \\ (SELECT * FROM USUARIO_NO_ACTIVO NATURAL JOIN USUARIO);
    , .{ nick, nick, nick });
    defer sql.getAllocator().free(lista_amigos);

    for (lista_amigos) |fila| {
        print("\n{s}", .{fila.nick});
    }

    print("\n", .{});

    while (true) {
        print("\n1. Añadir amigo\n2. Eliminar amigo\n3. Modificar tipo de usuario\n4. Darse de baja\n5. Atrás\n", .{});
        const input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => try addAmigo(nick),
            2 => try eliminarAmigo(nick),
            3 => try modificarTipo(nick),
            4 => try darBaja(nick),
            5 => break,
            else => unreachable,
        }
    }
}

fn menuMisCanciones(nick: []const u8) !void {
    while (true) {
        print("\n[MIS CANCIONES]\n", .{});
        print("\n1. Subir Canción\n2. Eliminar Canción\n3. Listar Canciones\n4. Atrás\n", .{});
        const input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => try subirCancion(nick),
            2 => try eliminarCancion(nick),
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
            1 => try crearContratoAutor(nick),
            2 => try crearContratoPromocion(nick),
            3 => try renovarContrato(),
            4 => break,
            else => {},
        }
    }
}

fn listarContratos(nick: []const u8) !void {
    const contratos_autor = try sql.query(
        Contrato,
        \\SELECT DISTINCT id_contrato, cuenta_bancaria, cantidad_pagada, fecha_creacion
        \\FROM contrato_autor NATURAL JOIN contrato NATURAL JOIN firma NATURAL JOIN cancion_sube
        \\WHERE nick = ?;
    ,
        .{nick},
    );
    defer sql.getAllocator().free(contratos_autor);

    const Cancion_Sube_Print = struct {
        id_cancion: u32,
        titulo: []const u8,
    };

    for (contratos_autor) |autor| {
        const canciones_autor = try sql.query(
            Cancion_Sube_Print,
            \\SELECT id_cancion, titulo
            \\FROM firma NATURAL JOIN cancion_sube
            \\WHERE id_contrato = ?;
        ,
            .{autor.id_contrato},
        );
        defer sql.getAllocator().free(canciones_autor);

        print(
            "\nContrato de autor: {d}\nCuenta bancaria: {s}\nCantidad pagada: {d}\nFecha de creación: {}\n",
            .{
                autor.id_contrato,
                autor.cuenta_bancaria,
                autor.cantidad_pagada,
                utils.fmtSqlDate(autor.fecha_creacion),
            },
        );
        print("Canciones contratadas:\n", .{});
        for (canciones_autor) |cancion| {
            print("Id: {d} - Titulo: {s}\n", .{ cancion.id_cancion, cancion.titulo });
        }
    }

    const contratos_promo = try sql.query(
        Contrato_Promocion,
        \\SELECT DISTINCT id_contrato, cuenta_bancaria, cantidad_pagada, fecha_creacion, fecha_caducidad
        \\FROM contrato_promocion NATURAL JOIN contrato NATURAL JOIN firma NATURAL JOIN cancion_sube
        \\WHERE nick = ?;
    ,
        .{nick},
    );
    defer sql.getAllocator().free(contratos_promo);

    for (contratos_promo) |promo| {
        const canciones_promo = try sql.query(
            Cancion_Sube_Print,
            \\SELECT id_cancion, titulo
            \\FROM firma NATURAL JOIN cancion_sube
            \\WHERE id_contrato = ?;
        ,
            .{promo.id_contrato},
        );
        defer sql.getAllocator().free(canciones_promo);

        print("\nContrato de promoción: {d}\nCuenta bancaria: {s}\nCantidad pagada: {d}\nFecha de creación: {}\nFecha de caducidad: {}\n", .{ promo.id_contrato, promo.cuenta_bancaria, promo.cantidad_pagada, utils.fmtSqlDate(promo.fecha_creacion), utils.fmtSqlDate(promo.fecha_caducidad) });
        print("Canciones contratadas:\n", .{});
        for (canciones_promo) |cancion| {
            print("Id: {d} - Titulo: {s}\n", .{ cancion.id_cancion, cancion.titulo });
        }
    }
}

fn anadirCancion(id_contrato: u32) !void {
    print("\nIntroduce el identificador de la canción:\n", .{});
    const id_cancion = try utils.readNumber(u8, stdin);

    sql.execute("BEGIN add_firma(?, ?); END;", .{ id_contrato, id_cancion }) catch |err| {
        const sql_err = sql.getLastError() orelse return err;
        defer sql_err.deinit();
        print("Error añadiendo firma: {s}\n", .{sql_err.msg});
        return;
    };

    sql.execute("BEGIN add_cancion(?, ?); END;", .{ id_cancion, id_contrato }) catch |err| {
        const sql_err = sql.getLastError() orelse return err;
        defer sql_err.deinit();
        print("Error añadiendo canción: {s}\n", .{sql_err.msg});
        return;
    };

    print("\nCanción añadida al contrato!\n", .{});
}

fn crearContratoAutor(nick: []const u8) !void {
    print("\nIntroduce cuenta bancaria en la que abonar:\n", .{});
    var buf_cuenta_banco: [consts.max_length.cuenta_banco]u8 = undefined;
    const cuenta_banco = try utils.readString(stdin, &buf_cuenta_banco);

    print("\nIntroduce la cantidad a pagar:\n", .{});
    const cantidad_pagar = try utils.readNumber(u32, stdin);

    const id_contrato = (try sql.querySingleValue(
        u32,
        \\SELECT MAX(id_contrato)
        \\FROM contrato;
    ,
        .{},
    )) orelse 0;

    try sql.createSavePoint("contrato_no_creado");
    try sql.execute("BEGIN crear_contrato_autor(?, ?, ?); END;", .{
        id_contrato + 1,
        cuenta_banco,
        cantidad_pagar,
    });
    try sql.createSavePoint("contrato_creado");

    while (true) {
        print("\nAquí le muestro sus canciones disponibles en SpotyCloud:\n", .{});
        try listarCancionesAutor(nick);
        print("\n1. Añadir canción al contrato\n2. Eliminar canciones seleccionadas\n3. Cancelar contrato\n4. Finalizar contrato\n", .{});
        const input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => try anadirCancion(id_contrato + 1),
            2 => try sql.rollbackToSavePoint("contrato_creado"),
            3 => try sql.rollbackToSavePoint("contrato_no_creado"),
            4 => break,
            else => {},
        }
    }

    print("\nProceso terminado!\n", .{});
    try sql.commit();
}

fn crearContratoPromocion(nick: []const u8) !void {
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

    const id_contrato = (try sql.querySingleValue(
        u32,
        \\SELECT MAX(id_contrato)
        \\FROM contrato;
    ,
        .{},
    )) orelse 0;
    try sql.createSavePoint("contrato_no_creado");
    try sql.execute("BEGIN crear_contrato_promocion(?, ?, ?, ?); END;", .{
        id_contrato + 1,
        cuenta_banco,
        cantidad_pagar,
        fecha_vencimiento,
    });
    try sql.createSavePoint("contrato_creado");

    while (true) {
        print("\nAquí le muestro sus canciones disponibles en SpotyCloud:\n", .{});
        try listarCancionesAutor(nick);
        print("\n1. Añadir canción al contrato\n2. Eliminar canciones seleccionadas\n3. Cancelar contrato\n4. Finalizar contrato\n", .{});
        const input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => try anadirCancion(id_contrato + 1),
            2 => try sql.rollbackToSavePoint("contrato_creado"),
            3 => try sql.rollbackToSavePoint("contrato_no_creado"),
            4 => break,
            else => {},
        }
    }

    try sql.commit();
    print("Proceso terminado!\n", .{});
}

fn renovarContrato() !void {
    print("\nIntroduce el indentificador del contrato de promoción que desea renovar:\n", .{});
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

    sql.execute("BEGIN renovar_contrato(?, ?); END;", .{ id_cont, fecha_renovacion }) catch |err| {
        const sql_err = sql.getLastError() orelse return err;
        defer sql_err.deinit();
        print("Error renovando contrato: {s}\n", .{sql_err.msg});
        return;
    };
    try sql.commit();
    print("\nContrato renovado!\n", .{});
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

fn listarPlaylists() !void {
    const playlists = try sql.query(
        Playlist,
        // Coge las playlists públicas
        // Quita las que son de usuarios no activos
        \\  (SELECT * FROM playlist_publica NATURAL JOIN playlists_crea)
        \\  MINUS
        \\ (SELECT id_playlist,nombre,fecha_creacion,nick FROM playlists_crea NATURAL JOIN usuario_no_activo);
    ,
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

fn addCancionPlaylist(id_playlist: u32) !void {
    print("\nIntroduce el id de la cancion a añadir:\n", .{});
    const id_cancion = try utils.readNumber(u32, stdin);

    sql.execute("BEGIN ADD_CANCION_PLAYLIST(?, ?); END;", .{ id_cancion, id_playlist }) catch |err| {
        const sql_err = sql.getLastError() orelse return err;
        defer sql_err.deinit();
        print("Error añadiendo canción a la playlist: {s}\n", .{sql_err.msg});
        return;
    };

    try sql.commit();

    print("Cacnión añadida.\n", .{});
}

fn eliminarCancionPlaylist(id_playlist: u32) !void {
    print("\nIntroduce el id de la cancion a eliminar:\n", .{});
    const id_cancion = try utils.readNumber(u32, stdin);

    sql.execute("BEGIN ELIMINAR_CANCION_PLAYLIST(?, ?); END;", .{ id_cancion, id_playlist }) catch |err| {
        const sql_err = sql.getLastError() orelse return err;
        defer sql_err.deinit();
        print("Error eliminando canción de la playlist: {s}\n", .{sql_err.msg});
        return;
    };

    try sql.commit();

    print("Cacnión eliminada.\n", .{});
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
            1 => try addCancionPlaylist(id_playlist),
            2 => try eliminarCancionPlaylist(id_playlist),
            3 => break,
            else => {},
        }
    }
}

fn menuCancion(id_cancion: u32) !void {
    // Precondición: existe una canción con ese id
    const cancion = (try sql.querySingle(
        Cancion_Sube,
        "SELECT * FROM cancion_sube WHERE id_cancion=?",
        .{id_cancion},
    )).?;

    print(
        "id: {}\ntitulo: {s}\n\nfecha: {}\netiqueta: {s}\nnick: {s}\n",
        .{ cancion.id_cancion, cancion.titulo, utils.fmtSqlDate(cancion.fecha), cancion.etiqueta, cancion.nick },
    );

    while (true) {
        print("\n1. Reproducir\n2. Añadir a playlist\n3. Evaluar\n4. Atrás\n", .{});
        const input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => try reproducirCancion(id_cancion),
            2 => try anadirAPlaylist(id_cancion),
            3 => try evaluar(id_cancion),
            4 => break,
            else => {},
        }
    }
}

fn reproducirCancion(id_cancion: u32) !void {
    // Precondición: id_cancion existe
    const archivo_enlace = (try sql.querySingleValue(
        []const u8,
        "SELECT archivo_enlace FROM cancion_sube WHERE id_cancion = ?;",
        .{id_cancion},
    )).?;

    // Comprobar si ya existe el archivo
    const archivo_nombre = std.fs.path.basename(archivo_enlace);
    const archivo_ruta = try std.fs.path.join(global_allocator, &.{ carpeta_musica_path, archivo_nombre });
    defer global_allocator.free(archivo_ruta);
    std.fs.cwd().access(archivo_ruta, .{ .read = true }) catch |err| switch (err) {
        error.FileNotFound => {
            // Descargar archivo
            print("Descargando archivo...\n", .{});
            utils.downloadFile(global_allocator, archivo_enlace, archivo_ruta) catch |err_download| {
                print("Ha ocurrido un error descargando el archivo: {}\n", .{err_download});
                return;
            };
        },
        else => return err,
    };

    print("Archivo disponible, reproduciendo!\n\n", .{});

    music.play(archivo_ruta) catch |err| {
        print("Ha ocurrido un error reproduciendo archivo: {}\n", .{err});
        return;
    };

    var reproduciendo = true;
    while (true) {
        if (reproduciendo) {
            print("1. Pausar\n", .{});
        } else {
            print("1. Reanudar\n", .{});
        }
        print("2. Salir\n", .{});

        const input = try utils.readNumber(u32, stdin);
        switch (input) {
            1 => {
                if (reproduciendo) music.pause() else music.resumeMusic();
                reproduciendo = !reproduciendo;
            },
            2 => {
                music.stop();
                break;
            },
            else => {},
        }
    }
}

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

    // Busca entre todos los usuarios pero quita los no activos
    const user = (try sql.querySingle(Usuario, "SELECT * FROM usuario WHERE nick=? MINUS (SELECT * FROM USUARIO_NO_ACTIVO NATURAL JOIN USUARIO);", .{nickname})) orelse {
        print("Error: usuario no encontrado\n", .{});
        return;
    };

    print("=== CANCIONES ===\n", .{});
    try listarCancionesAutor(nickname);
    print("\n=== PLAYLISTS ===\n", .{});
    try listarPlaylistsAutor(nickname);
}

fn listarCancionesPlaylist(id_playlist: u32) !void {
    print("\nCanciones de la playlist {d}:\n", .{id_playlist});
    var lista = try sql.query(Cancion_Sube,
    // Coge las canciones en la playlist
    // Y les quita las canciones que son de usuarios no activos
        \\ SELECT * FROM 
        \\  (SELECT id_cancion FROM contiene WHERE id_playlist = ? ) NATURAL JOIN cancion_sube
        \\ MINUS
        \\  SELECT id_cancion, titulo, archivo_enlace, fecha, etiqueta, nick 
        \\  FROM cancion_sube NATURAL JOIN usuario_no_activo;
    , .{id_playlist});
    defer sql.getAllocator().free(lista);

    for (lista) |fila| {
        print("{d}. {s} - {s}\n", .{ fila.id_cancion, fila.titulo, fila.nick });
    }
}

fn accederCancion() !void {
    print("Introduce el id de la canción.", .{});
    const id_cancion = try utils.readNumber(u32, stdin);

    // Comprobar que existe
    _ = (try sql.querySingleValue(
        u32,
        // Busca la canción entre las canciones activas, pero les quita las canciones de usuarios no activos
        "(SELECT * FROM cancion_activa WHERE id_cancion=?) MINUS (SELECT id_cancion FROM cancion_sube NATURAL JOIN usuario_no_activo);",
        .{id_cancion},
    )) orelse {
        print("Error: canción no encontrada\n", .{});
        return;
    };

    try menuCancion(id_cancion);
}

fn accederPlaylists() !void {
    print("Introduce el id de la playlist.", .{});
    const input = try utils.readNumber(u32, stdin);
    const id_playlist = (try sql.querySingleValue(u32,
        // Busca entre las playlists públicas
        // Quita de los resultados las que son de usuarios no activos
        \\  SELECT * FROM playlist_publica WHERE id_playlist=? 
        \\ MINUS 
        \\  (SELECT id_playlist FROM playlists_crea NATURAL JOIN usuario_no_activo);
    , .{input})) orelse {
        print("Error: playlist no encontrada\n", .{});
        return;
    };

    try listarCancionesPlaylist(id_playlist);
}

fn menuExplorar(nick: []const u8) !void {
    while (true) {
        print("\n1. Buscar canciones\n2. Buscar playlists\n3. Acceder a canción\n4. Acceder perfil\n5. Acceder a playlist\n6. Atrás\n", .{});
        const input = try utils.readNumber(usize, stdin);
        switch (input) {
            1 => try listarCancionesTitulo(),
            2 => try listarPlaylists(),
            3 => try accederCancion(),
            4 => try accederPerfil(),
            5 => try accederPlaylists(),
            6 => break,
            else => {},
        }
    }
}

fn esAutor(nick: []const u8) !bool {
    const count = try sql.querySingleValue(u32,
        \\ SELECT COUNT(*)
        \\ FROM autor
        \\ WHERE nick = ?;
    , .{nick});
    return count.? == 1;
}

fn menuPrincipal(nick: []const u8) !void {
    //Copio pego mi solución del menú cuenta para averiguar si eres autor o no. Probablemente haya formas mejores de hacerlo
    const es_autor = try esAutor(nick);

    while (true) {
        if (es_autor) {
            print("\n1. Mi cuenta\n2. Mis canciones\n3. Mis contratos\n4. Mis playlists\n5. Explorar\n6. Salir\n", .{});
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
        } else {
            print("\n1. Mi cuenta\n2. Mis playlists\n3. Explorar\n4. Salir\n", .{});
            const input = try utils.readNumber(usize, stdin);
            switch (input) {
                1 => try menuMiCuenta(nick),
                2 => try menuMisPlaylists(nick),
                3 => try menuExplorar(nick),
                4 => break,
                else => {},
            }
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
            2 => {
                nickname = (try register(&nickname_buf)) orelse continue;
                break;
            },
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

    try music.init();

    // Crear la carpeta donde se guardarán los archivos
    std.fs.cwd().makeDir(carpeta_musica_path) catch |err| if (err != error.PathAlreadyExists) return err;

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
