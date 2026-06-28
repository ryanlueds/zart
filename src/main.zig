const std = @import("std");
const rl = @import("raylib");
const util = @import("util.zig");

const GridPoint = struct {
    id: usize,
    col: i32,
    row: i32,
    coord: rl.Vector2,
    valid: bool,
    size: f32,
};

const pixels: i32 = 2000;
const border: f32 = 250;
const grain: i32 = 30;
const bubbles: i32 = 20;

pub fn main() anyerror!void {
    rl.initWindow(pixels, pixels, "zart");
    defer rl.closeWindow();
    for (100..110) |seed| {
        drawImage(@intCast(seed));
    }
}

fn drawCircle(
    grid_list: []GridPoint,
    radii: []f32,
    palette: [util.palettes[0].len][]const u8,
    rnd: std.Random
) void {
    const cell = util.sampleBuffer(GridPoint, grid_list, rnd);

    if (cell.valid) {
        const radius = util.sampleBuffer(f32, radii, rnd) * cell.size;
        const color = util.hexToColor(util.sampleBuffer([]const u8, &palette, rnd));
        
        const linewidth: f32 = 2 + radius / 3;
        const innerRadius = if (rnd.float(f32) < 0.5) radius - linewidth else 0;
        rl.drawRing(
            cell.coord,
            innerRadius,
            radius,
            0,
            360,
            100,
            color,
        );
    }
}

fn drawBarbell(
    grid_list: []GridPoint,
    radii: []f32,
    palette: [util.palettes[0].len][]const u8,
    rnd: std.Random
) void {
    const cell1 = util.sampleBuffer(GridPoint, grid_list, rnd);

    const isVertical = if (rnd.float(f32) < 0.7) true else false;
    var cell2: GridPoint = undefined;

    for (grid_list) |c| {
        const dr = if (c.row > cell1.row) c.row - cell1.row else cell1.row - c.row;
        const dc = if (c.col > cell1.col) c.col - cell1.col else cell1.col - c.col;

        if (isVertical and dr <= 5 and dc == 0) {
            cell2 = c;
            if (rnd.float(f32) < 0.1) {
                break;
            }
        } 
        else if (!isVertical and dr == 0 and dc <= 3) {
            cell2 = c;
            if (rnd.float(f32) < 0.2) {
                break;
            }
        }
    }

    if (cell1.valid and cell2.valid) {
        const radius = util.sampleBuffer(f32, radii, rnd);

        const color = util.hexToColor(util.sampleBuffer([]const u8, &palette, rnd));
        const linewidth: f32 = 2 + radius / 3;
        const innerRadius = radius - linewidth;

        rl.drawRing(
            cell1.coord,
            innerRadius,
            radius,
            0,
            360,
            100,
            color,
        );

        rl.drawRing(
            cell2.coord,
            innerRadius,
            radius,
            0,
            360,
            100,
            color,
        );

        var from: rl.Vector2 = undefined;
        var to: rl.Vector2 = undefined;
        if (isVertical) {
            if (cell2.coord.y > cell1.coord.y) {
                from = rl.Vector2{
                    .x = cell1.coord.x,
                    .y = cell1.coord.y + radius,
                };
                to = rl.Vector2{
                    .x = cell2.coord.x,
                    .y = cell2.coord.y - radius,
                };
            } else {
                from = rl.Vector2{
                    .x = cell1.coord.x,
                    .y = cell1.coord.y - radius,
                };
                to = rl.Vector2{
                    .x = cell2.coord.x,
                    .y = cell2.coord.y + radius,
                };
            }
        } else {
            if (cell2.coord.x > cell1.coord.x) {
                from = rl.Vector2{
                    .x = cell1.coord.x + radius,
                    .y = cell1.coord.y,
                };
                to = rl.Vector2{
                    .x = cell2.coord.x - radius,
                    .y = cell2.coord.y,
                };
            } else {
                from = rl.Vector2{
                    .x = cell1.coord.x - radius,
                    .y = cell1.coord.y,
                };
                to = rl.Vector2{
                    .x = cell2.coord.x + radius,
                    .y = cell2.coord.y,
                };
            }
        }

        
        rl.drawLineEx(from, to, linewidth, color);
    }
}

fn drawImage(seed: u32) void {
    // type std.Random.Xoshiro256
    var prng = std.Random.DefaultPrng.init(seed);
    const rnd = prng.random();
    // const iter: u32 = 100;
    // 3456 by 2234

    var grid_list: [grain * grain]GridPoint = undefined;

    // define a set of permissible grid points
    for (0..grain) |i| {
        for (0..grain) |j| {
            grid_list[i * grain + j] = GridPoint{
                .id = (i * grain + j),
                .col = @intCast(j),
                .row = @intCast(i),
                .coord = rl.Vector2.init(
                    ((pixels - border * 2) / (grain - 1)) * @as(f32, @floatFromInt(j)) + border,
                    ((pixels - border * 2) / (grain - 1)) * @as(f32, @floatFromInt(i)) + border,
                ),
                .valid = true,
                .size = 1,
            };
        }
    }

    for (0..bubbles) |i| {
        var cell = util.sampleBufferMutable(GridPoint, &grid_list, rnd);
        const aura: usize = if (i < bubbles / 2) 2 else 1;

        const isNotBorderPoint = (cell.row > aura and cell.row < (grain - aura))
            and (cell.col > aura and cell.col < (grain - aura));

        if (isNotBorderPoint) {
            var shouldMerge: bool = true;
            for (&grid_list) |*c| {
                const dr = if (c.row > cell.row) c.row - cell.row else cell.row - c.row;
                const dc = if (c.col > cell.col) c.col - cell.col else cell.col - c.col;

                if (dr <= aura and dc <= aura) {
                    if (!c.valid) shouldMerge = false;
                    c.valid = false;
                }
            }

            if (shouldMerge) {
                cell.valid = true;
                if (aura == 1) {
                    cell.size = 2.25;
                } else {
                    cell.size = 4.5;
                }
            }
        }
    }

    var radii: [6]f32 = undefined;
    for (0..6) |i| {
        radii[i] = (pixels / grain) * (0.2 + (@as(f32, @floatFromInt(i)) / 5) * 0.4);
    }

    // const palette = util.sampleBuffer([util.palettes[0].len][]const u8, &util.palettes, rnd);
    const palette = util.palettes[19];
    const background = util.hexToColor(util.sampleBuffer([]const u8, &palette, rnd));


    const renderTexture: rl.RenderTexture2D = rl.loadRenderTexture(pixels, pixels) catch unreachable;
    defer rl.unloadRenderTexture(renderTexture);

    // draw a background
    rl.beginTextureMode(renderTexture);
    rl.drawRectangle(0, 0, pixels, pixels, background);
    rl.endDrawing();


    // for (&grid_list) |grid_point| {
    //     rl.beginTextureMode(renderTexture);
    //     defer rl.endDrawing();
    //
    //     if (grid_point.valid) {
    //         rl.drawCircleV(
    //             grid_point.coord,
    //             grid_point.size,
    //             rl.Color.black,
    //         );
    //     }
    // }
    rl.beginTextureMode(renderTexture);
    defer rl.endDrawing();

    for (0..600) |_| {
        if (rnd.float(f32) < 0.80) {
            drawCircle(&grid_list, &radii, palette, rnd);
        } else {
            drawBarbell(&grid_list, &radii, palette, rnd);
        }
    }
    // for (0..pixels) |x| {
    //     const coord: i32 = @intCast(x);
    //     rl.imageDrawPixel(&image, coord, coord, util.hexToColor(util.palettes[0][0]));
    // }

    const image = rl.loadImageFromTexture(renderTexture.texture) catch unreachable;
    defer rl.unloadImage(image);

    var buf: [20]u8 = undefined;
    const fileName = std.fmt.bufPrintZ(&buf, "zart{}.png", .{seed}) catch unreachable;

    _ = rl.exportImage(image, fileName[0..]);
}
