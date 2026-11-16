const std = @import("std");
const goome = @import("goome");

var gradient_px: [128 * 128]u32 = undefined;

fn makeGradient() !goome.Bitmap {
    for (0..128) |y| {
        for (0..128) |x| {
            const r: u32 = @intCast(0x2a + x * (0x6f - 0x2a) / 127);
            const g: u32 = @intCast(0x40 + y * (0xdc - 0x40) / 127);
            const b: u32 = @intCast(0x9a - (x + y) * 0x50 / 254);
            gradient_px[y * 128 + x] = 0xFF000000 | r << 16 | g << 8 | b;
        }
    }
    return goome.Bitmap.fromArgb(&gradient_px, 128, 128);
}

fn setTheme(u: *goome.Ui, light: bool, accent: u32, own_accent: bool, r: f64, anim: f64, solid: bool) void {
    const t = u.theme();
    const f = t.font;
    if (light) u.themeLight() else u.themeDark();
    t.font = f;
    if (own_accent) t.accent = accent;
    t.radius = r;
    t.anim_ms = anim;
    if (solid) t.panel |= 0xFF000000;
}

fn fmtZ(buf: []u8, comptime fmt: []const u8, args: anytype) [*:0]const u8 {
    return (std.fmt.bufPrintZ(buf, fmt, args) catch return "").ptr;
}

pub fn main() !void {
    const g = goome.Goome.open(.{ .title = "goome ui", .no_capture = true }) catch |e| {
        std.debug.print("cant open an overlay: {s}\n", .{goome.strerror(goome.errorCode(e))});
        std.process.exit(1);
    };
    defer g.deinit();
    const u = g.ui() catch {
        std.debug.print("no memory for the ui\n", .{});
        std.process.exit(1);
    };
    defer u.deinit();
    var mons: [1]goome.Monitor = undefined;
    const ms = g.monitors(&mons);
    const area = if (ms.len > 0) ms[0].area else goome.rect(0, 0, 1280, 720);
    const ax: f64 = @floatFromInt(area.x);
    const ay: f64 = @floatFromInt(area.y);

    var have_logo = true;
    var logo = goome.Bitmap.load("docs/logo.png") catch goome.Bitmap.load("../docs/logo.png") catch blk: {
        have_logo = false;
        break :blk try makeGradient();
    };
    defer logo.deinit();

    var main_win: goome.Window = .{ .x = ax + 40, .y = ay + 40, .w = 440, .h = 620 };
    var stats: goome.Window = .{ .x = ax + 500, .y = ay + 40, .w = 280, .h = 0 };
    var tab: i32 = 0;
    var clicks: u32 = 0;
    var grid = true;
    var wifi = true;
    var notify = false;
    var mode: i32 = 1;
    var count: i32 = 42;
    var fruit: i32 = 2;
    var picked: i32 = -1;
    var more = true;
    var light: i32 = 0;
    var own_accent = false;
    var solid = false;
    var always = false;
    var img_clicks: u32 = 0;
    var running = true;
    const testing = std.mem.eql(u8, g.backendName(), "test");
    var volume: f64 = 0.65;
    var corner: f64 = 10;
    var anim: f64 = 120;
    var highlight: u32 = 0xFF4FA3FF;
    var accent: u32 = 0xFF6FDC5F;
    var name: [64]u8 = undefined;
    goome.setText(&name, "goome");
    var search: [64]u8 = [_]u8{0} ** 64;
    const fruits = [_][*:0]const u8{ "Mango", "Banana", "Cherry", "Kiwi", "Apple", "Lemon", "Grape", "Fig", "Dragonfruit", "Pear" };
    const tabs = [_][*:0]const u8{ "Widgets", "Images", "Theme", "About" };

    var spent: i64 = 0;
    var tframes: i64 = 0;
    var fps: f64 = 0;
    var frame_ms: f64 = 0;
    var acc_ms: f64 = 0;
    var acc_n: u32 = 0;
    var fps_n: u32 = 0;
    var fps_t = goome.nowMs();
    var pace: goome.Pacer = .{};
    var dirty = true;
    var buf: [96]u8 = undefined;
    while (running) {
        var wait: i32 = if (dirty or always or testing or u.animating()) pace.wait(60) else 500;
        while (try g.poll(wait)) |ev| {
            if (ev.kind == .quit) running = false;
            _ = u.feed(ev);
            dirty = true;
            wait = 0;
        }
        if (!running) break;
        if (!dirty and !always and !testing and !u.animating()) continue;
        dirty = false;

        const t0 = goome.nowMs();
        _ = u.begin(0) orelse continue;
        if (u.window("goome ui", &main_win, goome.win.move | goome.win.resize | goome.win.collapse)) {
            _ = u.tabs("tabs", &tabs, &tab);
            u.pushId(tabs[@intCast(tab)]);
            _ = u.scrollBegin("page", 0);
            switch (tab) {
                0 => {
                    u.heading("Buttons");
                    u.row(3);
                    if (u.button("Click me")) clicks += 1;
                    if (u.button("Reset")) clicks = 0;
                    _ = u.button("Hover me");
                    u.tooltip("hi :)");
                    if (clicks == 0) u.label("not clicked yet") else if (clicks == 1) u.label("clicked once") else u.labelFmt("clicked {d} times", .{clicks});
                    u.separator();
                    u.heading("Switches");
                    _ = u.checkbox("Show grid", &grid);
                    u.sameLine();
                    _ = u.checkbox("Notifications", &notify);
                    _ = u.toggle("Wi-Fi", &wifi);
                    _ = u.radio("Small", &mode, 0);
                    u.sameLine();
                    _ = u.radio("Medium", &mode, 1);
                    u.sameLine();
                    _ = u.radio("Large", &mode, 2);
                    u.separator();
                    u.heading("Values");
                    _ = u.slider("Volume", &volume, 0, 1, "%.2f");
                    _ = u.sliderInt("Count", &count, 0, 100);
                    const pct: i32 = @intFromFloat(volume * 100 + 0.5);
                    u.progress(volume, fmtZ(&buf, "{d}%", .{pct}));
                    u.progress(-1, null);
                    u.row(2);
                    _ = u.input("Name", &name);
                    _ = u.input("Search", &search);
                    _ = u.combo("Fruit", &fruit, &fruits);
                    _ = u.color("Highlight", &highlight);
                    if (u.collapsing("More stuff", &more)) {
                        u.wrapped("a long list so theres something to scroll. pick one, it shows up under it.");
                        _ = u.scrollBegin("list", 150);
                        for (0..30) |i| {
                            var item: [32]u8 = undefined;
                            if (u.selectable(fmtZ(&item, "Item {d}", .{i + 1}), picked == @as(i32, @intCast(i)))) picked = @intCast(i);
                        }
                        u.scrollEnd();
                        if (picked >= 0) u.labelFmt("picked item {d}", .{picked + 1}) else u.label("nothing picked");
                    }
                },
                1 => {
                    u.heading(if (have_logo) "docs/logo.png" else "Generated gradient");
                    u.image(&logo, 120, 120, 18);
                    u.sameLine();
                    u.image(&logo, 120, 120, 60);
                    u.sameLine();
                    u.image(&logo, 120, 120, 0);
                    u.label("image buttons");
                    for (0..4) |i| {
                        var id: [16]u8 = undefined;
                        if (i > 0) u.sameLine();
                        if (u.imageButton(fmtZ(&id, "img{d}", .{i}), &logo, 56, 56)) img_clicks += 1;
                    }
                    if (img_clicks == 0) u.label("no image clicks yet") else if (img_clicks == 1) u.label("one image click") else u.labelFmt("{d} image clicks", .{img_clicks});
                    u.image(&logo, 0, 90, 10);
                },
                2 => {
                    u.heading("Theme");
                    const was = light;
                    _ = u.radio("Dark", &light, 0);
                    u.sameLine();
                    _ = u.radio("Light", &light, 1);
                    var ch = light != was;
                    if (u.color("Accent", &accent)) {
                        own_accent = true;
                        ch = true;
                    }
                    if (u.slider("Corner radius", &corner, 0, 20, "%.0f px")) ch = true;
                    if (u.slider("Animation", &anim, 0, 400, "%.0f ms")) ch = true;
                    if (u.toggle("Solid panels", &solid)) ch = true;
                    if (u.button("Reset theme")) {
                        light = 0;
                        own_accent = false;
                        corner = 10;
                        anim = 120;
                        solid = false;
                        accent = 0xFF6FDC5F;
                        ch = true;
                    }
                    if (ch) setTheme(u, light != 0, accent, own_accent, corner, anim, solid);
                    if (!own_accent) accent = u.theme().accent;
                },
                else => {
                    u.heading("About");
                    u.wrapped("made with goome. try clicking next to this window, your desktop still gets it.");
                    u.labelFmt("goome {s} on {s}", .{ goome.version, g.backendName() });
                    u.labelFmt("{d:.0} fps, {d:.2} ms a frame", .{ fps, frame_ms });
                    if (!stats.isOpen() and u.button("Show stats")) stats.setOpen(true);
                },
            }
            u.scrollEnd();
            u.popId();
        }
        u.windowEnd();

        if (u.window("Stats", &stats, goome.win.move | goome.win.collapse | goome.win.close | goome.win.resize)) {
            u.labelFmt("{d:.0} fps", .{fps});
            u.labelFmt("{d:.2} ms a frame", .{frame_ms});
            const used: i32 = @intFromFloat(frame_ms * 100 / 16.7 + 0.5);
            u.progress(frame_ms / 16.7, fmtZ(&buf, "{d}% of a 60 fps frame", .{used}));
            _ = u.toggle("Redraw every frame", &always);
            if (u.button("Quit")) running = false;
        }
        u.windowEnd();
        u.end();

        const t1 = goome.nowMs();
        spent += t1 - t0;
        tframes += 1;
        acc_ms += @floatFromInt(t1 - t0);
        acc_n += 1;
        fps_n += 1;
        if (t1 - fps_t >= 500) {
            fps = @as(f64, @floatFromInt(fps_n)) * 1000.0 / @as(f64, @floatFromInt(t1 - fps_t));
            frame_ms = acc_ms / @as(f64, @floatFromInt(acc_n));
            fps_t = t1;
            fps_n = 0;
            acc_ms = 0;
            acc_n = 0;
        }
    }
    if (tframes > 0) std.debug.print("{d} frames, {d:.2} ms a frame\n", .{ tframes, @as(f64, @floatFromInt(spent)) / @as(f64, @floatFromInt(tframes)) });
}
