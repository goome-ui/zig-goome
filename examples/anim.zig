const std = @import("std");
const goome = @import("goome");
const c = goome.c;

const Row = struct { name: [*:0]const u8, ease: goome.Ease, color: u32 };

const rows = [_]Row{
    .{ .name = "linear", .ease = .linear, .color = 0xFF7C8CFF },
    .{ .name = "in", .ease = .in, .color = 0xFF4FB3F7 },
    .{ .name = "out", .ease = .out, .color = 0xFF3FC8B4 },
    .{ .name = "in out", .ease = .in_out, .color = 0xFF6FDC5F },
    .{ .name = "smooth", .ease = .smooth, .color = 0xFFE8D85A },
    .{ .name = "back", .ease = .back, .color = 0xFFFFB443 },
    .{ .name = "spring", .ease = .spring, .color = 0xFFFF7A59 },
    .{ .name = "bounce", .ease = .bounce, .color = 0xFFFF6FA8 },
};

const moods = [_]u32{ 0xFF2D6CDF, 0xFFE0483E, 0xFF21A66B, 0xFFF2B33D, 0x00000000 };
const mood_names = [_][]const u8{ "blue", "red", "green", "gold", "see through" };

fn fade(col: u32, k: f64) u32 {
    const kk = std.math.clamp(k, 0, 1);
    const a: u32 = @intFromFloat(@as(f64, @floatFromInt(col >> 24 & 255)) * kk + 0.5);
    return a << 24 | (col & 0xFFFFFF);
}

fn textAt(cv: *goome.Canvas, f: ?*goome.Font, size: f64, x: f64, cy: f64, s: [*:0]const u8, col: u32, center: bool) void {
    const m = if (f) |font| font.measure(size, s) else goome.measure(size, s);
    const h = if (m.h > 0) m.h else if (f) |font| font.lineHeight(size) else goome.lineHeight(size);
    _ = cv.fontText(f, size, if (center) x - m.w / 2 else x, @floor(cy - h / 2 + 0.5), s, col);
}

fn themeFont(u: *goome.Ui) ?*goome.Font {
    return @ptrCast(u.theme().font);
}

fn easeRows(u: *goome.Ui, side: bool) void {
    const th = u.theme();
    for (rows) |row| {
        var it: goome.Item = .{};
        _ = u.custom(row.name, 0, 30, c.GOOME_ITEM_NO_HIT, &it);
        const k = u.anim(row.name, if (side) 1 else 0, 900, row.ease);
        const cv = u.canvas() orelse continue;
        const tx = it.x + 86;
        const tw = it.w - 96;
        const bw: f64 = 46;
        const run = (tw - bw) * 0.76;
        const x = tx + (tw - bw - run) / 2 + k * run;
        textAt(cv, themeFont(u), 13, it.x + 4, it.y + 15, row.name, th.text_dim, false);
        cv.rrect(tx, it.y + 3, tw, 24, goome.radius(12), 0x14FFFFFF);
        cv.rect(tx + (tw - bw - run) / 2 + bw / 2, it.y + 14, 1, 2, 0x30FFFFFF);
        cv.rect(tx + (tw - bw - run) / 2 + run + bw / 2, it.y + 14, 1, 2, 0x30FFFFFF);
        cv.shadow(x, it.y + 8, bw, 16, 8, 8, fade(row.color, 0.45));
        cv.rrect(x, it.y + 6, bw, 18, goome.radius(9), row.color);
    }
}

fn colorCard(u: *goome.Ui, mood: *usize) void {
    const th = u.theme();
    var it: goome.Item = .{};
    _ = u.custom("mood", 0, 92, 0, &it);
    if (it.clicked != 0) mood.* = (mood.* + 1) % moods.len;
    u.tooltip("click for the next color");
    const col = u.animColor("mood", moods[mood.*], 600, .in_out);
    const lift = u.anim("mood lift", if (it.hovered != 0) 1 else 0, 160, .out);
    const cv = u.canvas() orelse return;
    const y = it.y - lift * 2;
    for (0..12) |i| cv.rect(it.x + @as(f64, @floatFromInt(i)) * it.w / 12, it.y + 8, it.w / 24, 76, 0x10FFFFFF);
    cv.shadow(it.x, y + 6, it.w, 84, 14, 18, fade(col, 0.4 + lift * 0.2));
    cv.rrect(it.x, y, it.w, 84, goome.radius(14), col);
    cv.ring(it.x + 30, y + 42, 12, 2, 0x50FFFFFF);
    var buf: [64]u8 = undefined;
    const s = std.fmt.bufPrintZ(&buf, "{s}  #{X:0>8}", .{ mood_names[mood.*], col }) catch return;
    textAt(cv, themeFont(u), 15, it.x + 54, y + 42, s, th.text, false);
}

fn springToggle(u: *goome.Ui, id: [*:0]const u8, on: *bool) void {
    const th = u.theme();
    var it: goome.Item = .{};
    _ = u.custom(id, 64, 36, c.GOOME_ITEM_FOCUSABLE, &it);
    const k = it.key & 0xFF;
    if (it.clicked != 0 or k == ' ' or k == goome.key.enter) on.* = !on.*;
    const pos = u.anim(id, if (on.*) 1 else 0, 520, .spring);
    const squish = u.anim("squish", if (it.held != 0) 1 else 0, 220, .spring);
    const track = u.animColor(id, if (on.*) th.accent else 0xFF3A3F49, 260, .out);
    const cv = u.canvas() orelse return;
    const x = it.x + 2;
    const y = it.y + 4;
    const w: f64 = 60;
    const h: f64 = 28;
    const r: f64 = 11;
    const kw = 2 * r + squish * 8;
    if (it.focused != 0) cv.rrect(x - 3, y - 3, w + 6, h + 6, goome.radius(17), fade(if (th.focus != 0) th.focus else th.accent, 0.6));
    cv.rrect(x, y, w, h, goome.radius(14), track);
    const kx = x + 3 + pos * (w - 6 - kw);
    cv.shadow(kx, y + 5, kw, 2 * r, r, 6, 0x60000000);
    cv.rrect(kx, y + 3, kw, 2 * r, goome.radius(r), 0xFFF4F5F7);
}

fn bell(u: *goome.Ui, count: *u32, kick: *bool) void {
    const th = u.theme();
    var it: goome.Item = .{};
    _ = u.custom("bell", 140, 64, 0, &it);
    if (it.clicked != 0) {
        count.* += 1;
        kick.* = true;
    }
    const drop = u.anim("drop", if (kick.*) -46 else 0, if (kick.*) 0 else 900, .bounce);
    const pop = u.anim("pop", if (kick.*) 0.4 else 1, if (kick.*) 0 else 500, .spring);
    const shown = u.anim("shown", if (count.* > 0) 1 else 0, 200, .out);
    kick.* = false;
    const cv = u.canvas() orelse return;
    const bg = u.animColor("bell bg", if (it.hovered != 0) 0xFF2E333C else 0xFF262A31, 140, .out);
    cv.rrect(it.x, it.y + 8, 120, 52, goome.radius(12), bg);
    textAt(cv, themeFont(u), 14, it.x + 60, it.y + 34, "notify me", th.text, true);
    if (shown <= 0.01) return;
    var buf: [16]u8 = undefined;
    const n = std.fmt.bufPrintZ(&buf, "{d}", .{count.*}) catch return;
    const r = 13 * pop;
    const cx = it.x + 116;
    const cy = it.y + 10 + drop;
    cv.shadow(cx - r, cy - r + 3, 2 * r, 2 * r, r, 8, fade(0x90000000, shown));
    cv.circle(cx, cy, r, fade(0xFFE0483E, shown));
    if (pop > 0.6) textAt(cv, themeFont(u), 12 * pop, cx, cy, n, fade(0xFFFFFFFF, shown), true);
}

pub fn main() !void {
    const g = goome.Goome.open(.{
        .title = "Animations",
        .mode = .window,
        .width = 880,
        .height = 760,
        .min_width = 620,
        .min_height = 700,
        .window_flags = goome.window_flags.resizable | goome.window_flags.center,
    }) catch |e| {
        std.debug.print("cant open a window: {s}\n", .{goome.strerror(goome.errorCode(e))});
        std.process.exit(1);
    };
    defer g.deinit();
    const u = g.ui() catch {
        std.debug.print("no memory for the ui\n", .{});
        std.process.exit(1);
    };
    defer u.deinit();
    const testing = std.mem.startsWith(u8, g.backendName(), "test");
    var running = true;
    var side = false;
    var autoplay = true;
    var mood: usize = 0;
    var on = false;
    var count: u32 = 0;
    var kick = false;
    var frame: i64 = 0;
    var flipped: i64 = 0;
    var pace: goome.Pacer = .{};
    while (running) {
        var wait: i32 = if (testing or autoplay or u.animating()) pace.wait(60) else 500;
        while (try g.poll(wait)) |ev| {
            if (ev.kind == .quit or ev.kind == .close) running = false;
            _ = u.feed(ev);
            wait = 0;
        }
        if (!running) break;
        const now = if (testing) frame * 16 else goome.nowMs();
        frame += 1;
        if (autoplay and now - flipped >= 1500) {
            flipped = now;
            side = !side;
            if (side) {
                mood = (mood + 1) % moods.len;
                on = !on;
                count += 1;
                kick = true;
            }
        }
        _ = u.begin(0) orelse continue;
        _ = u.app("Animations", c.GOOME_APP_STATUSBAR);
        u.heading("Every ease, same 900 ms");
        if (u.button("Swap sides")) {
            side = !side;
            flipped = now;
        }
        u.sameLine();
        _ = u.toggle("Play by itself", &autoplay);
        u.space(4);
        easeRows(u, side);
        u.space(8);
        u.heading("Color fade");
        colorCard(u, &mood);
        u.space(8);
        u.heading("Spring and bounce");
        springToggle(u, "springy", &on);
        u.sameLine();
        u.label(if (on) "on, and it wobbled a bit" else "off");
        u.sameLine();
        u.space(40);
        u.sameLine();
        bell(u, &count, &kick);
        u.statusbar(if (u.animating()) "moving" else "still");
        u.appEnd();
        u.end();
    }
}
