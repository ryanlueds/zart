const std = @import("std");
const rl = @import("raylib");
const Random = std.Random;

pub const width = 2560;
pub const height = 1664;

pub const palettes = [_][5][]const u8{
    .{ "#de9151", "#f34213", "#2e2e3a", "#bc5d2e", "#bbb8b2" },
    .{ "#a63446", "#fbfef9", "#0c6291", "#000004", "#7e1946" },
    .{ "#ffffff", "#ffcad4", "#b0d0d3", "#c08497", "#f7af9d" },
    .{ "#aa8f66", "#ed9b40", "#ffeedb", "#61c9a8", "#ba3b46" },
    .{ "#241023", "#6b0504", "#a3320b", "#d5e68d", "#47a025" },
    .{ "#64113f", "#de4d86", "#f29ca3", "#f7cacd", "#84e6f8" },
    .{ "#660000", "#990033", "#5f021f", "#8c001a", "#ff9000" },
    .{ "#c9cba3", "#ffe1a8", "#e26d5c", "#723d46", "#472d30" },
    .{ "#0e7c7b", "#17bebb", "#d4f4dd", "#d62246", "#4b1d3f" },
    .{ "#0a0908", "#49111c", "#f2f4f3", "#a9927d", "#5e503f" },
    .{ "#020202", "#0d324d", "#7f5a83", "#a188a6", "#9da2ab" },
    .{ "#c2c1c2", "#42213d", "#683257", "#bd4089", "#f51aa4" },
    .{ "#820263", "#d90368", "#eadeda", "#2e294e", "#ffd400" },
    .{ "#f4e409", "#eeba0b", "#c36f09", "#a63c06", "#710000" },
    .{ "#d9d0de", "#bc8da0", "#a04668", "#ab4967", "#0c1713" },
    .{ "#012622", "#003b36", "#ece5f0", "#e98a15", "#59114d" },
    .{ "#3c1518", "#69140e", "#a44200", "#d58936", "#fffb46" },
    .{ "#6e0d25", "#ffffb3", "#dcab6b", "#774e24", "#6a381f" },
    .{ "#bcabae", "#0f0f0f", "#2d2e2e", "#716969", "#fbfbfb" },
    .{ "#2b4162", "#385f71", "#f5f0f6", "#d7b377", "#8f754f" },
};

pub fn hexToColor(hex: []const u8) rl.Color {
    return .{
        .r = std.fmt.parseInt(u8, hex[1..3], 16) catch unreachable,
        .g = std.fmt.parseInt(u8, hex[3..5], 16) catch unreachable,
        .b = std.fmt.parseInt(u8, hex[5..7], 16) catch unreachable,
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

pub fn luma(c: rl.Color) f32 {
    return 0.299 * @as(f32, @floatFromInt(c.r)) +
        0.587 * @as(f32, @floatFromInt(c.g)) +
        0.114 * @as(f32, @floatFromInt(c.b));
}

fn lumaLess(_: void, a: rl.Color, b: rl.Color) bool {
    return luma(a) < luma(b);
}

// A palette padded with black/white and sorted dark to light, for ramp lookups.
pub fn buildAnchors(seed: u32) [7]rl.Color {
    const palette = palettes[seed % palettes.len];
    var anchors: [7]rl.Color = undefined;
    anchors[0] = rl.Color.black;
    anchors[1] = rl.Color.white;
    for (0..5) |i| anchors[i + 2] = hexToColor(palette[i]);
    std.mem.sort(rl.Color, &anchors, {}, lumaLess);
    return anchors;
}

fn lerpChannel(a: u8, b: u8, t: f32) u8 {
    const af: f32 = @floatFromInt(a);
    const bf: f32 = @floatFromInt(b);
    return @intFromFloat(af + (bf - af) * t);
}

pub fn rampColor(anchors: []const rl.Color, t: f32) rl.Color {
    const scaled = std.math.clamp(t, 0, 1) * @as(f32, @floatFromInt(anchors.len - 1));
    const lo: usize = @intFromFloat(@floor(scaled));
    const hi = @min(lo + 1, anchors.len - 1);
    const frac = scaled - @floor(scaled);
    return .{
        .r = lerpChannel(anchors[lo].r, anchors[hi].r, frac),
        .g = lerpChannel(anchors[lo].g, anchors[hi].g, frac),
        .b = lerpChannel(anchors[lo].b, anchors[hi].b, frac),
        .a = 255,
    };
}

// guassian blue
pub fn blur(values: []f32, w: usize, h: usize, radius: usize, gpa: std.mem.Allocator) !void {
    if (radius == 0) return;

    const ksize = radius * 2 + 1;
    const kernel = try gpa.alloc(f32, ksize);
    defer gpa.free(kernel);
    const sigma = @as(f32, @floatFromInt(radius)) / 2.0;
    var sum: f32 = 0;
    for (kernel, 0..) |*k, i| {
        const x: f32 = @floatFromInt(@as(isize, @intCast(i)) - @as(isize, @intCast(radius)));
        k.* = @exp(-(x * x) / (2 * sigma * sigma));
        sum += k.*;
    }
    for (kernel) |*k| k.* /= sum;

    const tmp = try gpa.alloc(f32, values.len);
    defer gpa.free(tmp);
    const wi: isize = @intCast(w);
    const hi: isize = @intCast(h);

    for (0..h) |y| {
        for (0..w) |x| {
            var acc: f32 = 0;
            for (kernel, 0..) |k, i| {
                const sx = std.math.clamp(@as(isize, @intCast(x)) + @as(isize, @intCast(i)) - @as(isize, @intCast(radius)), 0, wi - 1);
                acc += values[y * w + @as(usize, @intCast(sx))] * k;
            }
            tmp[y * w + x] = acc;
        }
    }
    for (0..h) |y| {
        for (0..w) |x| {
            var acc: f32 = 0;
            for (kernel, 0..) |k, i| {
                const sy = std.math.clamp(@as(isize, @intCast(y)) + @as(isize, @intCast(i)) - @as(isize, @intCast(radius)), 0, hi - 1);
                acc += tmp[@as(usize, @intCast(sy)) * w + x] * k;
            }
            values[y * w + x] = acc;
        }
    }
}

fn valueLess(values: []const f32, a: u32, b: u32) bool {
    return values[a] < values[b];
}

pub fn colorize(values: []const f32, out: [*]rl.Color, anchors: []const rl.Color, gpa: std.mem.Allocator) !void {
    const n = values.len;

    const order = try gpa.alloc(u32, n);
    defer gpa.free(order);
    for (order, 0..) |*o, i| o.* = @intCast(i);
    std.sort.pdq(u32, order, values, valueLess);

    const denom: f32 = @floatFromInt(n - 1);
    var i: usize = 0;
    while (i < n) {
        var j = i + 1;
        while (j < n and values[order[j]] == values[order[i]]) j += 1;
        const rank = @as(f32, @floatFromInt(i + j - 1)) / 2.0;
        const color = rampColor(anchors, rank / denom);
        for (order[i..j]) |p| out[p] = color;
        i = j;
    }
}

pub fn exportPng(image: rl.Image, comptime prefix: []const u8, seed: u32) void {
    var buf: [64]u8 = undefined;
    const name = std.fmt.bufPrintZ(&buf, prefix ++ "{}.png", .{seed}) catch unreachable;
    _ = rl.exportImage(image, name);
}

pub const Progress = struct {
    const bar_width = 32;

    label: []const u8,
    total: u64,
    done: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    stop: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn add(self: *Progress, n: u64) void {
        _ = self.done.fetchAdd(n, .monotonic);
    }

    pub fn finish(self: *Progress) void {
        self.done.store(self.total, .monotonic);
        self.stop.store(true, .release);
    }

    fn draw(self: *Progress) void {
        const total_f: f32 = @floatFromInt(self.total);
        const d_f: f32 = @floatFromInt(self.done.load(.monotonic));
        const frac = if (self.total == 0) 1.0 else std.math.clamp(d_f / total_f, 0, 1);
        const filled: usize = @intFromFloat(frac * bar_width);
        const pct: u32 = @intFromFloat(frac * 100);
        var bar: [bar_width]u8 = undefined;
        for (0..bar_width) |i| bar[i] = if (i < filled) '#' else '.';
        std.debug.print("\r{s} [{s}] {d:>3}%", .{ self.label, bar, pct });
    }

    pub fn monitor(self: *Progress) void {
        const ts = std.c.timespec{ .sec = 0, .nsec = 80 * std.time.ns_per_ms };
        while (!self.stop.load(.acquire)) {
            self.draw();
            _ = std.c.nanosleep(&ts, null);
        }
        self.draw();
        std.debug.print("\n", .{});
    }
};
