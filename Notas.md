~~~mysql
CREATE TABLE cancion_sube(
    id_cancion INTEGER PRIMARY KEY,
    titulo VARCHAR2(30),
    archivo BLOB,
    fecha DATE,
    duracion INTEGER,
    etiqueta VARCHAR(30)
);

CREATE TABLE cancion_activa(
    id_cancion INTEGER PRIMARY KEY REFERENCES cancion_sube(id_cancion)
);

CREATE TABLE cancion_promocionada(
    id_cancion INTEGER PRIMARY KEY REFERENCES cancion_activa(id_cancion)
);

CREATE TABLE cancion_vendida(
    id_cancion INTEGER PRIMARY KEY REFERENCES cancion_activa(id_cancion)
);

CREATE TABLE contrato(
    id_contrato INTEGER PRIMARY KEY,
    cuenta_bancaria VARCHAR2(30),
    cantidad_pagada NUMBER(5,2),
    fecha_caducidad DATE
);

CREATE TABLE contrato_autor(
    id_contrato INTEGER PRIMARY KEY REFERENCES contrato(id_contrato)
);

CREATE TABLE contrato_promocion(
    id_contrato INTEGER PRIMARY KEY REFERENCES contrato(id_contrato),
    fecha_caducidad DATE
);

CREATE TABLE firma(
    id_contrato INTEGER REFERENCES contrato(id_contrato),
    id_cancion INTEGER REFERENCES cancion_activa(id_cancion),
    CONSTRAINT clave_primaria_firma PRIMARY KEY(id_contrato, id_cancion)
);

CREATE TABLE playlists_crea(
    id_playlist INTEGER PRIMARY KEY,
    nombre VARCHAR2(30),
    fecha_creacion DATE,
    nick REFERENCES usuario(nick)
);

CREATE TABLE playlist_publica(
    id_playlist INTEGER PRIMARY KEY REFERENCES playlists_crea(id_playlist)
);

CREATE TABLE usuario(
    nick VARCHAR2(20) PRIMARY KEY,
    nombre VARCHAR2(20),
    apellidos VARCHAR2(20),
    correo VARCHAR2(40) UNIQUE,
    contrasena VARCHAR2(32),
    fecha_nacimiento DATE
);

CREATE TABLE autor(
    nick VARCHAR2(20) PRIMARY KEY REFERENCES usuario(nick)
);

CREATE TABLE usuario_no_activo(
    nick VARCHAR2(20) PRIMARY KEY REFERENCES usuario(nick)
);

CREATE TABLE amistarse(
    nick1 VARCHAR2(20) REFERENCES usuario(nick),
    nick2 VARCHAR2(20) REFERENCES usuario(nick),
    CONSTRAINT clave_primaria_amistarse PRIMARY KEY (nick1, nick2)
);

CREATE TABLE contiene(
    id_cancion REFERENCES cancion_sube(id_cancion),
    id_playlist REFERENCES playlists_crea(id_playlist),
    CONSTRAINT clave_primaria_contiene PRIMARY KEY (id_cancion, id_playlist)
)
~~~
