const std = @import("std");
const rl = @import("raylib");
const util = @import("util.zig");

pub fn main() anyerror!void {
    const pixels: i32 = 1000;

    var image: rl.Image = rl.genImageColor(pixels, pixels, rl.Color.black);
    defer rl.unloadImage(image);

    for (0..pixels) |x| {
        const coord: i32 = @intCast(x);
        rl.imageDrawPixel(&image, coord, coord, util.hexToColor(util.palettes[0][0]));
    }

    _ = rl.exportImage(image, "zart1.png");
}
