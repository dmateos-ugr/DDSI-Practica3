const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_mixer.h");
});

pub fn init() !void {
    if (sdl.SDL_Init(sdl.SDL_INIT_AUDIO) < 0)
        return error.InitSDL;

    if (sdl.Mix_OpenAudio(44100, sdl.MIX_DEFAULT_FORMAT, 2, 2048) < 0)
        return error.InitSDL;
}

var music_playing: ?*sdl.Mix_Music = null;

pub fn play(path: []const u8) !void {
    // Stop previous music if there was any
    stop();

    const music = sdl.Mix_LoadMUS(path.ptr) orelse return error.LoadMusic;

    if (sdl.Mix_PlayMusic(music, 1) < 0)
        return error.PlayMusic;

    music_playing = music;
}

pub fn pause() void {
    if (sdl.Mix_PlayingMusic() == 1)
        sdl.Mix_PauseMusic();
}

pub fn resumeMusic() void {
    if (sdl.Mix_PlayingMusic() == 1 and sdl.Mix_PausedMusic() == 1)
        sdl.Mix_ResumeMusic();
}

pub fn stop() void {
    if (sdl.Mix_PlayingMusic() == 1)
        _ = sdl.Mix_HaltMusic();

    if (music_playing) |music| {
        sdl.Mix_FreeMusic(music);
        music_playing = null;
    }
}
