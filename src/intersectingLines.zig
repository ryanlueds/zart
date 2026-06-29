const std = @import("std");
const rl = @import("raylib");
const zart = @import("zart");

const width = zart.width;
const height = zart.height;
const scale_px = @min(width, height);

const layers = 20;
const iterations = 30_000_000;
const zoom = 0.10;
const blur_radius = 2;
const gamma = 1.7;

const seed_start = 300;
const seed_end = 399;
const image_count = seed_end - seed_start;

const Variant = enum {
    identity,
    celestialSphere1,
    celestialSphere2,
    lissajous1,
    lissajous2,
    rotation,

    pub fn len() usize {
        return @typeInfo(Variant).@"enum".fields.len;
    }
};

fn rasterData(values: []f32, rnd: std.Random, progress: *zart.Progress) void {
    var coeffs = std.mem.zeroes([9][layers]f32);
    for (0..9) |i| {
        for (0..layers) |j| {
            coeffs[i][j] = rnd.float(f32) * 4 - 2;
        }
    }

    const x_offset = rnd.float(f32) - 0.5;
    const y_offset = rnd.float(f32) - 0.5;
    const r_offset = rnd.float(f32) * 6.28;
    const s_offset = rnd.float(f32) * 6.28;
    const scale = rnd.float(f32) * 4 + 2;

    var s: f32 = 0.0;
    var u: f32 = 0.3;

    var x_old = rnd.float(f32) * 2 - 1;
    var y_old = rnd.float(f32) * 2 - 1;
    var z_old = rnd.float(f32) * 2 - 1;

    var x_tmp: f32 = 0.0;
    var y_tmp: f32 = 0.0;

    var x: f32 = 0;
    var y: f32 = 0;
    var z: f32 = 0;

    const v_shift: f32 = 1.0;
    const n_sym: u32 = 1 + rnd.uintLessThan(u32, 5);

    var since: u32 = 0;
    for (0..iterations) |_| {
        since += 1;
        if (since == 1 << 18) {
            progress.add(since);
            since = 0;
        }
        const layer = rnd.uintLessThan(usize, layers);
        const variant: Variant = @enumFromInt(rnd.uintLessThan(usize, Variant.len()));

        x = x_old + coeffs[0][layer] * x_old + coeffs[1][layer] * y_old + coeffs[2][layer];
        y = y_old + coeffs[3][layer] * x_old + coeffs[4][layer] * y_old + coeffs[5][layer];
        z = z_old + coeffs[6][layer] * x_old + coeffs[7][layer] * y_old + coeffs[8][layer];

        switch (variant) {
            .identity => {
                s = x * x + y * y + z * z + 2;
                x += v_shift * x / s;
                y += v_shift * y / s;
                z += v_shift * z / s;
                if (z < 0) z = 0;
            },
            .celestialSphere1 => {
                s = @cos(x * y);
                x = @cos(x) + x_offset;
                y = @cos(y) - 1.2 + y_offset;
                u = x * x + y * y;
                x_tmp = s * x / u;
                y_tmp = s * y / u;
                x = x_tmp * @cos(r_offset) - y_tmp * @sin(r_offset);
                y = x_tmp * @sin(r_offset) + y_tmp * @cos(r_offset);
                z = 1 + @sin(z);
            },
            .celestialSphere2 => {
                s = @cos(x * y);
                x = @cos(x) + x_offset;
                y = @cos(y) - 0.9 + y_offset;
                u = x * x + y * y;
                x_tmp = scale * s * x / u;
                y_tmp = scale * s * y / u;
                x = x_tmp * @cos(r_offset) - y_tmp * @sin(r_offset);
                y = x_tmp * @sin(r_offset) + y_tmp * @cos(r_offset);
                z = 1 + @sin(z);
            },
            .lissajous1 => {
                s = x * y;
                x_tmp = @cos(s) * @sin(s);
                y_tmp = @sin(s);
                x = x_tmp * @cos(s_offset) - y_tmp * @sin(s_offset);
                y = x_tmp * @sin(s_offset) + y_tmp * @cos(s_offset);
                z = 1 + @sin(z);
            },
            .lissajous2 => {
                s = x * y + s_offset;
                x_tmp = @cos(s) * scale * @sin(s);
                y_tmp = @sin(s) * scale;
                x = x_tmp * @cos(s_offset) - y_tmp * @sin(s_offset);
                y = x_tmp * @sin(s_offset) + y_tmp * @cos(s_offset);
                z = 1 + @sin(z);
            },
            .rotation => {
                const k = rnd.uintLessThan(u32, n_sym + 2);
                const rr = r_offset + 6.28 * @as(f32, @floatFromInt(k)) / @as(f32, @floatFromInt(n_sym + 1));
                x = x_tmp * @cos(rr) - y_tmp * @sin(rr);
                y = x_tmp * @sin(rr) + y_tmp * @cos(rr);
                z = z / 2 + rr / 2;
            }
        }

        const col = x * scale_px * zoom + width / 2;
        const row = y * scale_px * zoom + height / 2;
        if (col >= 0 and col < width and row >= 0 and row < height) {
            const ci: usize = @intFromFloat(col);
            const ri: usize = @intFromFloat(row);
            const idx = ri * width + ci;
            values[idx] += 1;
        }

        x_old = x;
        y_old = y;
        z_old = z * 0.5 + z_old * 0.5;
    }
    progress.add(since);
}

fn drawImage(seed: u32, gpa: std.mem.Allocator, progress: *zart.Progress) !rl.Image {
    var prng = std.Random.DefaultPrng.init(seed);

    const n = @as(usize, width) * @as(usize, height);
    const values = try gpa.alloc(f32, n);
    defer gpa.free(values);
    @memset(values, 0);
    rasterData(values, prng.random(), progress);
    try zart.blur(values, width, height, blur_radius, gpa);

    const image = rl.genImageColor(width, height, rl.Color.black);
    const data: [*]rl.Color = @ptrCast(@alignCast(image.data));
    const anchors = zart.buildAnchors(seed);
    zart.tonemap(values, data, &anchors, gamma);
    return image;
}

fn worker(seed: u32, gpa: std.mem.Allocator, progress: *zart.Progress) void {
    const image = drawImage(seed, gpa, progress) catch |err| {
        std.debug.print("\nseed {} failed: {}\n", .{ seed, err });
        return;
    };
    defer rl.unloadImage(image);
    zart.exportPng(image, "intersectingLines", seed);
}

pub fn main() anyerror!void {
    rl.setTraceLogLevel(.warning);
    const gpa = std.heap.page_allocator;

    var progress = zart.Progress{ .label = "intersectingLines", .total = image_count * iterations };
    const mon = try std.Thread.spawn(.{}, zart.Progress.monitor, .{&progress});

    var threads: [image_count]std.Thread = undefined;
    var i: usize = 0;
    for (seed_start..seed_end) |seed| {
        threads[i] = try std.Thread.spawn(.{}, worker, .{ @as(u32, @intCast(seed)), gpa, &progress });
        i += 1;
    }
    for (&threads) |t| t.join();

    progress.finish();
    mon.join();
}
