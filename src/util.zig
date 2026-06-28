const std = @import("std");
const rl = @import("raylib");
const Random = std.Random;

pub const palettes = [_][5][]const u8{
    .{"#de9151", "#f34213", "#2e2e3a", "#bc5d2e", "#bbb8b2"},
    .{"#a63446", "#fbfef9", "#0c6291", "#000004", "#7e1946"},
    .{"#ffffff", "#ffcad4", "#b0d0d3", "#c08497", "#f7af9d"},
    .{"#aa8f66", "#ed9b40", "#ffeedb", "#61c9a8", "#ba3b46"},
    .{"#241023", "#6b0504", "#a3320b", "#d5e68d", "#47a025"},
    .{"#64113f", "#de4d86", "#f29ca3", "#f7cacd", "#84e6f8"},
    .{"#660000", "#990033", "#5f021f", "#8c001a", "#ff9000"},
    .{"#c9cba3", "#ffe1a8", "#e26d5c", "#723d46", "#472d30"},
    .{"#0e7c7b", "#17bebb", "#d4f4dd", "#d62246", "#4b1d3f"},
    .{"#0a0908", "#49111c", "#f2f4f3", "#a9927d", "#5e503f"},
    .{"#020202", "#0d324d", "#7f5a83", "#a188a6", "#9da2ab"},
    .{"#c2c1c2", "#42213d", "#683257", "#bd4089", "#f51aa4"},
    .{"#820263", "#d90368", "#eadeda", "#2e294e", "#ffd400"},
    .{"#f4e409", "#eeba0b", "#c36f09", "#a63c06", "#710000"},
    .{"#d9d0de", "#bc8da0", "#a04668", "#ab4967", "#0c1713"},
    .{"#012622", "#003b36", "#ece5f0", "#e98a15", "#59114d"},
    .{"#3c1518", "#69140e", "#a44200", "#d58936", "#fffb46"},
    .{"#6e0d25", "#ffffb3", "#dcab6b", "#774e24", "#6a381f"},
    .{"#bcabae", "#0f0f0f", "#2d2e2e", "#716969", "#fbfbfb"},
    .{"#2b4162", "#385f71", "#f5f0f6", "#d7b377", "#8f754f"}
};

pub fn hexToColor(hex: []const u8) rl.Color {
    const r = std.fmt.parseInt(u8, hex[1..3], 16) catch unreachable;
    const g = std.fmt.parseInt(u8, hex[3..5], 16) catch unreachable;
    const b = std.fmt.parseInt(u8, hex[5..7], 16) catch unreachable;

    return rl.Color{
        .r = r,
        .g = g,
        .b = b,
        .a = 255,
    };
}

pub fn sampleBuffer(comptime T: type, buffer: []const T, rnd: Random) T {
    std.debug.assert(buffer.len > 0);
    return buffer[rnd.uintAtMost(usize, buffer.len - 1)];
}

pub fn sampleBufferMutable(comptime T: type, buffer: []T, rnd: Random) *T {
    std.debug.assert(buffer.len > 0);
    return &buffer[rnd.uintAtMost(usize, buffer.len - 1)];
}
