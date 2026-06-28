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
const iterations: u32 = 100;

const seed_start = 100;
const seed_end = 110;
const image_count = seed_end - seed_start;

const ExportJob = struct {
    image: rl.Image,
    seed: u32,
};

fn exportWorker(job: ExportJob) void {
    var buf: [20]u8 = undefined;
    const fileName = std.fmt.bufPrintZ(&buf, "zart{}.png", .{job.seed}) catch unreachable;
    _ = rl.exportImage(job.image, fileName);
    rl.unloadImage(job.image);
}

fn ringSegments(radius: f32) i32 {
    return std.math.clamp(@as(i32, @intFromFloat(radius)), 16, 96);
}

pub fn main() anyerror!void {
    rl.initWindow(pixels, pixels, "zart");
    defer rl.closeWindow();

    var threads: [image_count]std.Thread = undefined;
    var i: usize = 0;
    for (seed_start..seed_end) |seed| {
        const image = drawImage(@intCast(seed));
        threads[i] = std.Thread.spawn(
            .{},
            exportWorker,
            .{ExportJob{ .image = image, .seed = @intCast(seed) }},
        ) catch unreachable;
        i += 1;
    }
    for (&threads) |t| t.join();
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
            ringSegments(radius),
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
    if (!cell1.valid) return;

    const isVertical = rnd.float(f32) < 0.7;

    var candidates: [10]GridPoint = undefined;
    var count: usize = 0;
    for (grid_list) |c| {
        if (!c.valid or c.id == cell1.id) continue;
        const dr = if (c.row > cell1.row) c.row - cell1.row else cell1.row - c.row;
        const dc = if (c.col > cell1.col) c.col - cell1.col else cell1.col - c.col;

        const inSlice = if (isVertical) (dr <= 5 and dc == 0) else (dr == 0 and dc <= 3);
        if (inSlice) {
            candidates[count] = c;
            count += 1;
        }
    }

    if (count == 0) return;

    const cell2 = util.sampleBuffer(GridPoint, candidates[0..count], rnd);

    {
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
            ringSegments(radius),
            color,
        );

        rl.drawRing(
            cell2.coord,
            innerRadius,
            radius,
            0,
            360,
            ringSegments(radius),
            color,
        );

        const dir = if (isVertical)
            rl.Vector2{ .x = 0, .y = std.math.sign(cell2.coord.y - cell1.coord.y) }
        else
            rl.Vector2{ .x = std.math.sign(cell2.coord.x - cell1.coord.x), .y = 0 };

        const from = rl.Vector2{
            .x = cell1.coord.x + dir.x * radius,
            .y = cell1.coord.y + dir.y * radius,
        };
        const to = rl.Vector2{
            .x = cell2.coord.x - dir.x * radius,
            .y = cell2.coord.y - dir.y * radius,
        };

        rl.drawLineEx(from, to, linewidth, color);
    }
}

fn drawImage(seed: u32) rl.Image {
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

    const palette = util.palettes[19];
    const background = util.hexToColor(util.sampleBuffer([]const u8, &palette, rnd));


    const renderTexture: rl.RenderTexture2D = rl.loadRenderTexture(pixels, pixels) catch unreachable;
    defer rl.unloadRenderTexture(renderTexture);

    rl.beginTextureMode(renderTexture);
    defer rl.endTextureMode();

    rl.drawRectangle(0, 0, pixels, pixels, background);
    for (0..iterations) |_| {
        if (rnd.float(f32) < 0.80) {
            drawCircle(&grid_list, &radii, palette, rnd);
        } else {
            drawBarbell(&grid_list, &radii, palette, rnd);
        }
    }

    return rl.loadImageFromTexture(renderTexture.texture) catch unreachable;
}
