const std = @import("std");
const rl = @import("raylib");
const zart = @import("zart");

const GridPoint = struct {
    id: usize,
    col: i32,
    row: i32,
    coord: rl.Vector2,
    valid: bool,
    size: f32,
};

const width = zart.width;
const height = zart.height;
const border = 80;
const spacing = 50;
const bubbles = 20;
const iterations = 1000;

const cols = @divFloor(width - 2 * border, spacing) + 1;
const rows = @divFloor(height - 2 * border, spacing) + 1;
const cols_i: i32 = cols;
const rows_i: i32 = rows;
const spacing_f: f32 = spacing;
const margin_x: f32 = (width - (cols - 1) * spacing) / 2.0;
const margin_y: f32 = (height - (rows - 1) * spacing) / 2.0;

const seed_start = 100;
const seed_end = 110;
const image_count = seed_end - seed_start;

const ExportJob = struct {
    image: rl.Image,
    seed: u32,
    progress: *zart.Progress,
};

fn exportWorker(job: ExportJob) void {
    zart.exportPng(job.image, "dots", job.seed);
    rl.unloadImage(job.image);
    job.progress.add(1);
}

fn ringSegments(radius: f32) i32 {
    return std.math.clamp(@as(i32, @intFromFloat(radius)), 16, 96);
}

fn drawCircle(grid_list: []GridPoint, radii: []f32, palette: [zart.palettes[0].len][]const u8, rnd: std.Random) void {
    const cell = zart.sampleBuffer(GridPoint, grid_list, rnd);

    if (cell.valid) {
        const radius = zart.sampleBuffer(f32, radii, rnd) * cell.size;
        const color = zart.hexToColor(zart.sampleBuffer([]const u8, &palette, rnd));

        const linewidth: f32 = 2 + radius / 3;
        const innerRadius = if (rnd.float(f32) < 0.5) radius - linewidth else 0;
        rl.drawRing(cell.coord, innerRadius, radius, 0, 360, ringSegments(radius), color);
    }
}

fn drawBarbell(grid_list: []GridPoint, radii: []f32, palette: [zart.palettes[0].len][]const u8, rnd: std.Random) void {
    const cell1 = zart.sampleBuffer(GridPoint, grid_list, rnd);
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

    const cell2 = zart.sampleBuffer(GridPoint, candidates[0..count], rnd);

    const radius = zart.sampleBuffer(f32, radii, rnd);
    const color = zart.hexToColor(zart.sampleBuffer([]const u8, &palette, rnd));
    const linewidth: f32 = 2 + radius / 3;
    const innerRadius = radius - linewidth;

    rl.drawRing(cell1.coord, innerRadius, radius, 0, 360, ringSegments(radius), color);
    rl.drawRing(cell2.coord, innerRadius, radius, 0, 360, ringSegments(radius), color);

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

fn drawImage(seed: u32) rl.Image {
    var prng = std.Random.DefaultPrng.init(seed);
    const rnd = prng.random();

    var grid_list: [cols * rows]GridPoint = undefined;
    for (0..rows) |i| {
        for (0..cols) |j| {
            grid_list[i * cols + j] = .{
                .id = i * cols + j,
                .col = @intCast(j),
                .row = @intCast(i),
                .coord = rl.Vector2.init(
                    margin_x + spacing_f * @as(f32, @floatFromInt(j)),
                    margin_y + spacing_f * @as(f32, @floatFromInt(i)),
                ),
                .valid = true,
                .size = 1,
            };
        }
    }

    for (0..bubbles) |i| {
        var cell = zart.sampleBufferMutable(GridPoint, &grid_list, rnd);
        const aura: i32 = if (i < bubbles / 2) 2 else 1;

        const isNotBorderPoint = (cell.row > aura and cell.row < rows_i - aura) and
            (cell.col > aura and cell.col < cols_i - aura);

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
                cell.size = if (aura == 1) 2.25 else 4.5;
            }
        }
    }

    var radii: [6]f32 = undefined;
    for (0..6) |i| {
        radii[i] = spacing_f * (0.2 + (@as(f32, @floatFromInt(i)) / 5) * 0.4);
    }

    const palette = zart.palettes[19];
    const background = zart.hexToColor(zart.sampleBuffer([]const u8, &palette, rnd));

    const renderTexture: rl.RenderTexture2D = rl.loadRenderTexture(width, height) catch unreachable;
    defer rl.unloadRenderTexture(renderTexture);

    rl.beginTextureMode(renderTexture);
    rl.drawRectangle(0, 0, width, height, background);
    for (0..iterations) |_| {
        if (rnd.float(f32) < 0.80) {
            drawCircle(&grid_list, &radii, palette, rnd);
        } else {
            drawBarbell(&grid_list, &radii, palette, rnd);
        }
    }
    rl.endTextureMode(); // flushes the batch before readback

    return rl.loadImageFromTexture(renderTexture.texture) catch unreachable;
}

pub fn main() anyerror!void {
    rl.setTraceLogLevel(.warning);
    rl.initWindow(width, height, "zart");
    defer rl.closeWindow();

    var progress = zart.Progress{ .label = "dots", .total = image_count };
    const mon = try std.Thread.spawn(.{}, zart.Progress.monitor, .{&progress});

    var threads: [image_count]std.Thread = undefined;
    var i: usize = 0;
    for (seed_start..seed_end) |seed| {
        const image = drawImage(@intCast(seed));
        threads[i] = std.Thread.spawn(
            .{},
            exportWorker,
            .{ExportJob{ .image = image, .seed = @intCast(seed), .progress = &progress }},
        ) catch unreachable;
        i += 1;
    }
    for (&threads) |t| t.join();

    progress.finish();
    mon.join();
}
