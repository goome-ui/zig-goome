const std = @import("std");
const goome = @import("goome");
const c = goome.c;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const alloc = std.testing.allocator;

fn fnv(px: []const u32, w: usize, h: usize, stride: usize) u32 {
    var v: u32 = 2166136261;
    for (0..h) |y| {
        for (px[y * stride ..][0..w]) |p| {
            inline for (0..4) |k| {
                v = (v ^ ((p >> (k * 8)) & 255)) *% 16777619;
            }
        }
    }
    return v;
}

fn zeroCols(px: []const u32, stride: usize, h: usize, x0: usize, x1: usize) bool {
    for (0..h) |y| {
        for (px[y * stride + x0 .. y * stride + x1]) |p| if (p != 0) return false;
    }
    return true;
}

const structs = .{
    .{ "goome_opts", c.goome_opts },
    .{ "goome_rect", c.goome_rect },
    .{ "goome_monitor", c.goome_monitor },
    .{ "goome_image", c.goome_image },
    .{ "goome_canvas", c.goome_canvas },
    .{ "goome_event", c.goome_event },
    .{ "goome_pacer", c.goome_pacer },
    .{ "goome_radii", c.goome_radii },
    .{ "goome_bitmap", c.goome_bitmap },
    .{ "goome_theme", c.goome_theme },
    .{ "goome_skin", c.goome_skin },
    .{ "goome_ui_item", c.goome_ui_item },
    .{ "goome_combo", c.goome_combo },
    .{ "goome_ui_config", c.goome_ui_config },
};

fn sizeOfStruct(name: []const u8) ?usize {
    inline for (structs) |s| {
        if (std.mem.eql(u8, s[0], name)) return @sizeOf(s[1]);
    }
    return null;
}

fn fieldOf(name: []const u8, field: []const u8) ?[2]usize {
    inline for (structs) |s| {
        if (std.mem.eql(u8, s[0], name)) {
            inline for (std.meta.fields(s[1])) |f| {
                if (std.mem.eql(u8, f.name, field)) return .{ @offsetOf(s[1], f.name), @sizeOf(f.type) };
            }
        }
    }
    return null;
}

test "struct layout matches C" {
    const out = @embedFile("layout.txt");
    var lines = std.mem.tokenizeAny(u8, out, "\r\n");
    var n: usize = 0;
    while (lines.next()) |ln| {
        var parts = std.mem.tokenizeScalar(u8, ln, ' ');
        const name = parts.next().?;
        const a = try std.fmt.parseInt(usize, parts.next().?, 10);
        if (std.mem.indexOfScalar(u8, name, '.')) |dot| {
            const b = try std.fmt.parseInt(usize, parts.next().?, 10);
            const got = fieldOf(name[0..dot], name[dot + 1 ..]) orelse {
                std.debug.print("no zig field for {s}\n", .{name});
                return error.MissingField;
            };
            if (got[0] != a or got[1] != b) std.debug.print("{s}: c {d} {d}, zig {d} {d}\n", .{ name, a, b, got[0], got[1] });
            try expectEqual(a, got[0]);
            try expectEqual(b, got[1]);
        } else {
            const got = sizeOfStruct(name) orelse return error.MissingStruct;
            try expectEqual(a, got);
        }
        n += 1;
    }
    try expect(n > 200);
}

test "mirrored structs match C" {
    try expectEqual(@sizeOf(c.goome_event), @sizeOf(goome.Event));
    const cf = std.meta.fields(c.goome_event);
    const zf = std.meta.fields(goome.Event);
    try expectEqual(cf.len, zf.len);
    inline for (cf, zf) |a, b| {
        try expectEqual(@offsetOf(c.goome_event, a.name), @offsetOf(goome.Event, b.name));
        try expectEqual(@sizeOf(a.type), @sizeOf(b.type));
    }
    try expectEqual(@sizeOf(f64) * 4 + @sizeOf(c_int), @offsetOf(goome.Window, "open") + @sizeOf(c_int));
}

test "constants" {
    try expectEqual(@as(c_int, 0x90), goome.key.left);
    try expectEqual(@as(c_int, 0x400), goome.mod.alt);
    try expectEqual(@as(c_int, 7), @intFromEnum(goome.Backend.@"test"));
    try expectEqual(@as(c_int, 12), @intFromEnum(goome.EventType.drop));
    try expectEqual(@as(c_int, 256), goome.cap.grab);
    try expectEqual(@as(c_int, 16), goome.win.close);
    try expectEqual(@as(c_int, -5), goome.errorCode(error.Again));
    try expect(goome.toError(c.GOOME_ENOTSUP) == error.NotSupported);
    try expect(goome.strerror(c.GOOME_ENOTSUP).len > 0);
    try expectEqualStrings("0.4.0", goome.version);
}

test "combos" {
    try expectEqual(goome.Combo{ .key = 'h', .mods = goome.mod.alt }, try goome.parseCombo("alt+h"));
    try expectEqual(goome.Combo{ .key = goome.key.f1 + 4, .mods = goome.mod.ctrl | goome.mod.shift }, try goome.parseCombo("Ctrl+Shift+F5"));
    try expectEqual(goome.Combo{ .key = '/', .mods = goome.mod.alt | goome.mod.shift }, try goome.parseCombo("alt+?"));
    try expectEqual(goome.Combo{ .key = ' ', .mods = goome.mod.super }, try goome.parseCombo("super+space"));
    try expectEqual(goome.Combo{ .key = goome.key.left, .mods = goome.mod.super }, try goome.parseCombo("cmd+left"));
    try expectEqual(goome.Combo{ .key = 'h', .mods = goome.mod.shift }, try goome.parseCombo("H"));
    for ([_][*:0]const u8{ "alt+", "alt+f13", "" }) |bad| {
        try expect(std.meta.isError(goome.parseCombo(bad)));
    }
}

test "pacer" {
    var p: goome.Pacer = .{};
    try expectEqual(@as(i32, 0), p.wait(50));
    const w = p.wait(50);
    try expect(w > 0 and w <= 20);
    const t = goome.nowMs();
    try expect(t >= 0 and goome.nowMs() >= t);
}

const script = "screen 640x360 2; 1 click 20,20; 1 click 300,300; 2 hotkey alt+j; 3 key Hi\\b; 4 send ping; 5 scroll 30,30 -1; 6 hold 25,25 8; end 10";

test "scripted run" {
    const g = try goome.Goome.open(.{ .title = "t", .backend = .@"test", .test_script = script });
    defer g.deinit();
    try expect(std.mem.startsWith(u8, g.backendName(), "test"));
    var mons: [4]goome.Monitor = undefined;
    const ms = g.monitors(&mons);
    try expectEqual(@as(usize, 1), ms.len);
    try expectEqual(@as(c_int, 640), ms[0].area.w);
    try expectEqual(@as(f64, 2), ms[0].scale);
    try expectEqual(@as(c_int, 1280), ms[0].pw);
    try g.hotkey("alt+j", 7);
    try g.keyboard(true);
    var downs: usize = 0;
    var ups: usize = 0;
    var hot: usize = 0;
    var keys: usize = 0;
    var ctl: usize = 0;
    var scrolls: usize = 0;
    var held: usize = 0;
    var typed: [32]u8 = undefined;
    var tn: usize = 0;
    var quit = false;
    var frames: usize = 0;
    while (!quit and frames < 100) {
        const cv = g.begin(0) orelse return error.NoCanvas;
        try expectEqual(@as(f64, 2), cv.scale());
        try expectEqual(@as(usize, 1280), cv.width());
        cv.rect(10, 10, 40, 40, 0xFF336699);
        try g.end(cv, &.{goome.rect(10, 10, 40, 40)});
        frames += 1;
        if (g.pointer()) |p| {
            if (p.buttons != 0) held += 1;
        }
        var wait: i32 = 1;
        while (try g.poll(wait)) |ev| {
            wait = 0;
            switch (ev.kind) {
                .down => downs += 1,
                .up => ups += 1,
                .hotkey => {
                    if (ev.id == 7) hot += 1;
                },
                .key => {
                    keys += 1;
                    const s = ev.typed();
                    @memcpy(typed[tn..][0..s.len], s);
                    tn += s.len;
                },
                .control => {
                    if (std.mem.eql(u8, ev.message(), "ping")) ctl += 1;
                },
                .scroll => {
                    if (ev.dy == -1) scrolls += 1;
                },
                .quit => quit = true,
                else => {},
            }
        }
    }
    try expectEqual(@as(usize, 2), downs);
    try expectEqual(@as(usize, 2), ups);
    try expectEqual(@as(usize, 1), hot);
    try expectEqual(@as(usize, 3), keys);
    try expectEqualStrings("Hi", typed[0..tn]);
    try expectEqual(@as(usize, 1), ctl);
    try expectEqual(@as(usize, 1), scrolls);
    try expect(quit);
    try expect(held >= 1);

    const img = try g.capture(0, goome.rect(10, 10, 40, 40));
    try expectEqual(@as(usize, 80), img.width());
    try expectEqual(@as(usize, 80), img.height());
    try expect(img.raw.has_self != 0);
    try expectEqual(@as(u32, 0xFF336699), img.pixel(0, 0));
    try expectEqual(@as(u32, 0xFF336699), img.pixels()[0]);
    try expectEqual(80 * img.stride(), img.pixels().len);
    try expectEqual(img.pixel(79, 79), img.row(79)[79]);
    try expectEqual(@as(u8, 255), g.alphaAt(20, 20));
    try expectEqual(@as(u8, 0), g.alphaAt(200, 200));

    const again = try g.capture(0, null);
    try expectEqual(@as(usize, 1280), again.width());
    try expectEqual(@as(usize, 720), again.height());
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try tmp.dir.realpathAlloc(alloc, ".");
    defer alloc.free(dir);
    const path = try std.fs.path.joinZ(alloc, &.{ dir, "grab.ppm" });
    defer alloc.free(path);
    try again.savePpm(path);
    var head: [2]u8 = undefined;
    const f = try std.fs.openFileAbsolute(path, .{});
    defer f.close();
    _ = try f.readAll(&head);
    try expectEqualStrings("P6", &head);
}

test "errors come back as zig errors" {
    try std.testing.expectError(error.NoDisplay, goome.Goome.open(.{ .backend = .@"test", .test_frames = "no/such/frames" }));
    const g = try goome.Goome.open(.{ .backend = .@"test", .test_script = "end 3" });
    defer g.deinit();
    try expect(g.controlPath() == null);
    try expectEqual(goome.Mode.overlay, g.mode());
    const cv = g.begin(0) orelse return error.NoCanvas;
    cv.rect(0, 0, 10, 10, 0xFFFF0000);
    try g.end(cv, &.{goome.rect(0, 0, 10, 10)});
    try expectEqual(@as(u8, 255), g.alphaAt(5, 5));
    try std.testing.expectError(error.BadArgument, goome.Bitmap.fromArgb(&.{ 1, 2 }, 2, 2));
}

test "control fifo" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try tmp.dir.realpathAlloc(alloc, ".");
    defer alloc.free(dir);
    const dirz = try alloc.dupeZ(u8, dir);
    defer alloc.free(dirz);
    const g = goome.Goome.open(.{ .backend = .@"test", .state_dir = dirz, .test_script = "end 50" }) catch return;
    defer g.deinit();
    if (g.controlPath() == null) return;
    try goome.send(dirz, "hello there");
    var got = false;
    for (0..40) |_| {
        const cv = g.begin(0) orelse break;
        try g.end(cv, &.{});
        while (try g.poll(5)) |ev| {
            if (ev.kind == .control and std.mem.eql(u8, ev.message(), "hello there")) got = true;
        }
        if (got) break;
    }
    try expect(got);
}

const star = [_][2]f64{ .{ 80, 5 }, .{ 98, 85 }, .{ 40, 35 }, .{ 120, 35 }, .{ 62, 85 } };

const shape_hashes = [3][14]u32{
    .{ 0xA7B3B4C5, 0x0FB29A82, 0x1A98CF16, 0x1E7B729F, 0x21FD3B05, 0x241CE7FD, 0x6910B0D5, 0x7180B28E, 0x6F33AC30, 0xB48ADFA3, 0x796B9105, 0x2D93DC92, 0x1F908FAD, 0x23A6CF0C },
    .{ 0x73429A18, 0xD9BD97AB, 0xD031F56C, 0xD2D9FA9A, 0xD639A1A7, 0xA77C3E9E, 0x7BD3FEAD, 0xAC76561E, 0x5BD0648D, 0xD0AC70E1, 0x0BB5DDA0, 0xE7C304C7, 0xCCEF8860, 0xEFC1F212 },
    .{ 0x9175788F, 0x6E99EA87, 0x935CC8E1, 0x0B73F68D, 0x23891BE5, 0xA28476C1, 0xEA64F655, 0x87DC9430, 0x909D11B5, 0x0550BB7A, 0x6455EE86, 0xD8C08E2B, 0xFD0DD1FD, 0x28C27977 },
};

fn shape(cv: *goome.Canvas, k: usize, b: *const goome.Bitmap) void {
    const white = 0xFFFFFFFF;
    switch (k) {
        0 => cv.rrect(10.3, 8.6, 120, 70.2, goome.corners(4, 20, 0, 33), 0xE02060C0),
        1 => cv.rrectLine(10.3, 8.6, 120, 70.2, goome.radius(18), 2.5, 0xFF20A060),
        2 => cv.rrectGrad(10, 10, 130, 70, goome.radius(12), 0xFF102040, 0x8080C0FF, false),
        3 => cv.rrectGrad(10, 10, 130, 70, goome.radius(35), 0xFFFF4080, 0x004080FF, true),
        4 => cv.shadow(30, 20, 90, 50, 10, 16, 0x80000000),
        5 => {
            cv.circle(50.5, 50.2, 30.7, 0xFFFFC020);
            cv.circle(120, 30, 1.3, 0xFF000000);
        },
        6 => cv.ring(80, 50, 30, 5, 0xC0208080),
        7 => {
            cv.arc(50, 50, 30, 6, 0.3, 4.5, 0xFF3060E0);
            cv.arc(120, 50, 20, 30, 2, 2.5, 0xFF905020);
        },
        8 => cv.poly(&star, 0xFF2040A0),
        9 => cv.bitmap(b, 10, 10, 100.5, 75.3, goome.radius(20), white),
        10 => cv.bitmap(b, 10, 10, 24, 16, goome.radius(0), 0x80FF8080),
        11 => cv.bitmap(b, 10, 10, 9, 5, goome.radius(2), white),
        12 => cv.bitmapPart(b, 4, 2, 8, 8, 100, 10, 40, 40, white),
        else => {
            cv.clipPush(20, 15, 80, 50);
            cv.rrect(0, 0, 160, 100, goome.radius(30), 0xFF4080FF);
            cv.clipPush(50, 0, 100, 40);
            cv.circle(70, 40, 30, 0xFFFF4040);
            _ = cv.text(30, 30, "clip", true, 0xFF000000);
            cv.shadow(40, 20, 60, 30, 8, 10, 0xFF000000);
            cv.bitmap(b, 40, 10, 48, 32, goome.radius(6), white);
            cv.clipPop();
            cv.line(0, 0, 160, 100, 3, 0xFF00A000);
            cv.poly(&star, 0x80000000);
            cv.clipPop();
            cv.frame(20, 15, 80, 50, 1, 0x80000000);
        },
    }
}

fn makeBitmap(px: *[27 * 16]u32) goome.Bitmap {
    @memset(px, 0);
    for (0..16) |y| {
        for (0..24) |x| {
            const a: u32 = @intCast(x * 255 / 23);
            const v: u32 = if ((x / 4 + y / 4) & 1 != 0) 0xFFFFFF else 0x2050C0;
            px[y * 27 + x] = a << 24 | ((v >> 16 & 255) * a / 255) << 16 | ((v >> 8 & 255) * a / 255) << 8 | (v & 255) * a / 255;
        }
    }
    return goome.Bitmap.wrap(px, 24, 16, 27);
}

test "drawing basics" {
    var oc = try goome.OwnedCanvas.init(alloc, 160, 100, 200, 1.5);
    defer oc.deinit();
    const cv = oc.canvas();
    cv.roundRect(5, 5, 60, 40, 8, 0xC0203040);
    cv.line(0, 0, 100, 60, 3, 0xFFFF0000);
    cv.triangle(10, 50, 60, 50, 35, 10, 0x8000FF00);
    _ = cv.text(8, 8, "goome!", true, 0xFFFFFFFF);
    cv.frame(70, 10, 30, 30, 2, 0xFF00FFFF);
    const px = cv.pixels();
    for (0..100) |y| try expectEqual(@as(u32, 0), px[y * 200 + 170]);
    try expect(cv.raw().dx1 > cv.raw().dx0 and cv.raw().dy1 > cv.raw().dy0);
    try expectEqual(@as(u32, 0xB93B60CF), fnv(px, 200, 100, 200));
    cv.clear();
    for (px) |p| try expectEqual(@as(u32, 0), p);
    try expect(cv.textWidth("abc", false) > 0);
}

test "shape hashes match C at 3 scales" {
    var bp: [27 * 16]u32 = undefined;
    const b = makeBitmap(&bp);
    for ([_]f64{ 1, 1.25, 2 }, 0..) |sc, s| {
        for (0..14) |k| {
            const w: usize = @intFromFloat(160 * sc);
            const h: usize = @intFromFloat(100 * sc);
            var oc = try goome.OwnedCanvas.init(alloc, w, h, w + 3, sc);
            defer oc.deinit();
            const cv = oc.canvas();
            shape(cv, k, &b);
            const px = cv.pixels();
            const got = fnv(px, w + 3, h, w + 3);
            if (got != shape_hashes[s][k]) std.debug.print("scale {d} shape {d}: {x:0>8} want {x:0>8}\n", .{ sc, k, got, shape_hashes[s][k] });
            try expectEqual(shape_hashes[s][k], got);
            try expect(cv.raw().dx1 > cv.raw().dx0);
            try expect(zeroCols(px, w + 3, h, w, w + 3));
            for (px) |p| {
                const a = p >> 24;
                try expect((p >> 16 & 255) <= a and (p >> 8 & 255) <= a and (p & 255) <= a);
            }
            if (k == 13) {
                const x0: usize = @intFromFloat(20 * sc + 0.5);
                const y0: usize = @intFromFloat(15 * sc + 0.5);
                const x1: usize = @intFromFloat(100 * sc + 0.5);
                const y1: usize = @intFromFloat(65 * sc + 0.5);
                var cc = try goome.OwnedCanvas.init(alloc, w, h, w + 3, sc);
                defer cc.deinit();
                const cl = cc.canvas();
                cl.clipPush(20, 15, 80, 50);
                shape(cl, 8, &b);
                shape(cl, 4, &b);
                shape(cl, 9, &b);
                _ = cl.text(0, 20, "outside", true, 0xFFFFFFFF);
                const r = cl.raw();
                try expect(r.dx0 >= x0 and r.dy0 >= y0 and r.dx1 <= x1 and r.dy1 <= y1 and r.dx1 > r.dx0);
                const cpx = cl.pixels();
                for (0..h) |y| {
                    for (0..w) |x| {
                        if ((x < x0 or x >= x1 or y < y0 or y >= y1) and cpx[y * (w + 3) + x] != 0) return error.DrewOutsideClip;
                    }
                }
                cl.clipPop();
                try expectEqual(@as(c_int, 0), cl.raw().nclip);
            }
        }
    }
}

test "image and blit" {
    var src = try goome.OwnedCanvas.init(alloc, 20, 20, 20, 1);
    defer src.deinit();
    const green = [_]u32{0xFF00FF00} ** 16;
    src.canvas().image(0, 0, 20, 20, &green, 4, 4);
    try expectEqual(@as(u32, 0xFF00FF00), src.canvas().pixels()[0]);
    var dst = try goome.OwnedCanvas.init(alloc, 40, 40, 40, 1);
    defer dst.deinit();
    dst.canvas().blit(src.canvas(), 1.0, 10, 10);
    try expectEqual(@as(u32, 0xFF00FF00), dst.canvas().pixels()[10 * 40 + 10]);
    try expectEqual(@as(u32, 0), dst.canvas().pixels()[0]);
    dst.canvas().erase(0, 0, 40, 40);
    try expectEqual(@as(u32, 0), dst.canvas().pixels()[10 * 40 + 10]);
}

const Img = struct { name: []const u8, w: usize, h: usize, hash: u32 };

const images = [_]Img{
    .{ .name = "png-gray-1-bit.png", .w = 9, .h = 3, .hash = 0x01975AD8 },
    .{ .name = "png-palette-4-bit-trns-interlaced.png", .w = 6, .h = 6, .hash = 0xAF77E7E2 },
    .{ .name = "png-rgb-16-bit.png", .w = 5, .h = 4, .hash = 0xDD60C23E },
    .{ .name = "png-gray-alpha-stored-interlaced.png", .w = 5, .h = 5, .hash = 0x52D68985 },
    .{ .name = "png-rgba-fixed-huffman-split.png", .w = 8, .h = 6, .hash = 0x66DB9DCD },
    .{ .name = "png-gray-key.png", .w = 7, .h = 4, .hash = 0x843ED605 },
    .{ .name = "png-rgba-16-bit-interlaced.png", .w = 9, .h = 9, .hash = 0xDC2F91D5 },
    .{ .name = "jpeg-420.jpg", .w = 16, .h = 16, .hash = 0x32E2C9CE },
    .{ .name = "jpeg-422-restarts.jpg", .w = 13, .h = 9, .hash = 0x0E230BAF },
    .{ .name = "jpeg-444.jpg", .w = 10, .h = 10, .hash = 0x34FC5275 },
    .{ .name = "jpeg-progressive-420-restarts.jpg", .w = 14, .h = 11, .hash = 0x5BCEE932 },
    .{ .name = "jpeg-gray.jpg", .w = 9, .h = 7, .hash = 0xF010B3C8 },
    .{ .name = "jpeg-exif-rotated.jpg", .w = 6, .h = 10, .hash = 0x65909E25 },
    .{ .name = "bmp-4-bit.bmp", .w = 5, .h = 3, .hash = 0x9256D097 },
    .{ .name = "bmp-32-bit-alpha-top-down.bmp", .w = 3, .h = 2, .hash = 0x6BDB3A29 },
    .{ .name = "bmp-24-bit.bmp", .w = 5, .h = 3, .hash = 0x09D94C56 },
    .{ .name = "ppm.ppm", .w = 3, .h = 2, .hash = 0xC6FDF725 },
    .{ .name = "pgm-16-bit.pgm", .w = 3, .h = 1, .hash = 0x35029201 },
    .{ .name = "qoi.qoi", .w = 6, .h = 4, .hash = 0x23AF45AD },
};

test "bitmap hashes match C" {
    inline for (images) |im| {
        const raw = @embedFile("data/" ++ im.name);
        var b = try goome.Bitmap.loadMem(raw);
        try expectEqual(im.w, b.width());
        try expectEqual(im.h, b.height());
        try expect(b.owned());
        try expectEqual(im.hash, fnv(b.pixels(), b.width(), b.height(), b.stride()));
        b.deinit();
        try expect(b.pixels().len == 0);
        b.deinit();
        if (goome.Bitmap.loadMem(raw[0 .. raw.len / 2])) |half| {
            var hb = half;
            try expect(hb.width() > 0);
            hb.deinit();
        } else |_| {}
    }
}

test "bitmap errors" {
    try std.testing.expectError(error.NotSupported, goome.Bitmap.loadMem(@embedFile("data/jpeg-arithmetic.jpg")));
    try expect(std.mem.indexOf(u8, goome.bitmapError(), "arithmetic") != null);
    try std.testing.expectError(error.NotSupported, goome.Bitmap.loadMem("GIF89a......"));
    try expect(std.meta.isError(goome.Bitmap.loadMem("\x89PNG\r\n\x1a\n")));
    try expect(std.meta.isError(goome.Bitmap.load("no/such/file.png")));
    var b = try goome.Bitmap.fromArgb(&.{ 0xFFFF0000, 0x80FFFFFF, 0x00123456, 0x40804020 }, 2, 2);
    defer b.deinit();
    try std.testing.expectEqualSlices(u32, &.{ 0xFFFF0000, 0x80808080, 0, 0x40201008 }, b.pixels());
}

test "font hashes match C" {
    const ttf = @embedFile("data/dejavu-sub.ttf");
    const otf = @embedFile("data/dejavu-sub.otf");
    try expect(std.meta.isError(goome.Font.loadMem("nope, not a font", true)));
    try expect(std.meta.isError(goome.Font.loadMem(ttf[0..40], false)));
    const f = try goome.Font.loadMem(ttf, false);
    defer f.deinit();
    const o = try goome.Font.loadMem(otf, true);
    defer o.deinit();
    const m = f.measure(20, "goome!");
    try expect(m.w > 76.97 and m.w < 76.98 and m.h > 23.2 and m.h < 23.3);
    for ([_]*goome.Font{ f, o }) |font| {
        try expect(font.width(20, "AV") < font.width(20, "A") + font.width(20, "V") - 1);
    }
    const m2 = f.measure(20, "a\nbb\n");
    try expect(m2.h > 3 * 23.2 and m2.h < 3 * 23.3);
    try expect(f.width(20, "\xff\xc3(\xed\xa0\x80\xf4\x90\x80\x80") > 0);
    try expect(f.lineHeight(20) > 0);
    const want = [_]u32{ 0x412C299F, 0xBCD42095 };
    for ([_]*goome.Font{ f, o }, 0..) |font, k| {
        var oc = try goome.OwnedCanvas.init(alloc, 200, 120, 240, 1.5);
        defer oc.deinit();
        const cv = oc.canvas();
        const r = cv.raw();
        r.kx1 = 200;
        r.ky1 = 120;
        _ = cv.fontText(font, 13, 4, 2, "goome! Hié\nAVAWAY Ty.@ ☃", 0xFFFFFFFF);
        _ = cv.fontText(font, 30, 2.3, 24, "Hig", 0xC0FF8040);
        r.kx0 = 30;
        r.ky0 = 60;
        r.kx1 = 90;
        r.ky1 = 100;
        r.nclip = 1;
        _ = cv.fontText(font, 40, 10, 50, "WoW", 0xFF2080FF);
        const px = cv.pixels();
        try expect(zeroCols(px, 240, 120, 200, 240));
        for (px[100 * 240 ..]) |p| try expectEqual(@as(u32, 0), p);
        try expect(r.dx0 >= 0 and r.dx1 <= 200 and r.dy1 <= 100 and r.dx1 > r.dx0);
        try expectEqual(want[k], fnv(px, 240, 120, 240));
    }
    var oc = try goome.OwnedCanvas.init(alloc, 200, 120, 240, 1);
    defer oc.deinit();
    try expectEqual(goome.measure(12, "abc").w, oc.canvas().fontText(null, 12, 0, 0, "ab\nabc", 0xFFFFFFFF));
    try expect(goome.fontCount() >= 1);
    goome.setFont(0);
    try expect(goome.lineHeight(12) > 0);
}

const ui_script = "screen 400x360 1; 1 click 35,71; 2 click 29,106; 3 hold 40,157 6; 4 hover 120,157; " ++
    "7 click 100,213; 8 key ab; 9 key \\n; 10 key zz; 11 click 120,273; 13 click 120,206; " ++
    "15 click 300,20; 16 hold 100,20 20; 18 hover 150,40; end 22";

test "ui kit scripted run matches C" {
    const g = try goome.Goome.open(.{ .backend = .@"test", .test_script = ui_script });
    defer g.deinit();
    const u = try g.ui();
    defer u.deinit();
    u.theme().font = null;
    u.theme().font_size = 14;
    var w: goome.Window = .{ .x = 10, .y = 10, .w = 220, .h = 0 };
    var val: f64 = 0;
    var check: bool = false;
    var pick: i32 = 0;
    var text: [16]u8 = [_]u8{0} ** 16;
    var quit = false;
    var frames: usize = 0;
    var clicks: usize = 0;
    var downs: usize = 0;
    var keys_off: usize = 0;
    var kb_seen = false;
    var hashes: [3]u32 = .{ 0, 0, 0 };
    const picks = [_][*:0]const u8{ "one", "two", "three" };
    while (!quit and frames < 100) {
        while (try g.poll(0)) |ev| {
            if (ev.kind == .quit) quit = true;
            if (ev.kind == .down) downs += 1;
            if (ev.kind == .key and frames > 10) keys_off += 1;
            _ = u.feed(ev);
        }
        const cv = u.begin(0) orelse return error.NoCanvas;
        if (u.window("test", &w, goome.win.move)) {
            if (u.button("Go")) clicks += 1;
            _ = u.checkbox("Check", &check);
            _ = u.slider("Val", &val, 0, 1, null);
            _ = u.input("Text", &text);
            _ = u.combo("Pick", &pick, &picks);
        }
        u.windowEnd();
        u.end();
        if (frames == 8) kb_seen = goome.text(&text).len > 0;
        const slot: ?usize = switch (frames) {
            0 => 0,
            12 => 1,
            21 => 2,
            else => null,
        };
        if (slot) |s| hashes[s] = fnv(cv.pixels(), cv.width(), cv.height(), cv.stride());
        frames += 1;
    }
    try expectEqual(@as(usize, 1), clicks);
    try expect(check);
    try expect(val > 0.45 and val < 0.55);
    try expect(kb_seen);
    try expectEqualStrings("ab", goome.text(&text));
    try expectEqual(@as(usize, 0), keys_off);
    try expectEqual(@as(i32, 1), pick);
    try expectEqual(@as(f64, 60), w.x);
    try expectEqual(@as(f64, 30), w.y);
    try expectEqual(@as(usize, 7), downs);
    try expectEqual([3]u32{ 0x51713294, 0xb52f16c5, 0xea01692c }, hashes);
}

test "ui widgets and label" {
    const g = try goome.Goome.open(.{ .backend = .@"test", .test_script = "screen 800x600 1; 2 click 60,80; end 6" });
    defer g.deinit();
    const u = try g.ui();
    defer u.deinit();
    u.theme().font = null;
    u.themeLight();
    try expect(u.theme().text >> 24 > 0);
    u.themeDark();
    u.theme().accent = 0xFF6FDC5F;
    var main: goome.Window = .{ .x = 20, .y = 20, .w = 400 };
    var stats: goome.Window = .{ .x = 500, .y = 20, .w = 200 };
    var logo = try goome.Bitmap.fromArgb(&([_]u32{0xFF2A409A} ** 64), 8, 8);
    defer logo.deinit();
    var tab: i32 = 0;
    var vol: f64 = 0.5;
    var n: i32 = 3;
    var color: u32 = 0xFF4FA3FF;
    var mode: i32 = 1;
    var on = false;
    var more = true;
    var name: [64]u8 = undefined;
    goome.setText(&name, "hi");
    var body: [256]u8 = undefined;
    goome.setText(&body, "line one\nline two");
    var split: f64 = 0.4;
    var col: i32 = 0;
    var desc = false;
    var modal_open: c_int = 0;
    const tabs = [_][*:0]const u8{ "A", "B" };
    const plot = [_]f32{ 1, 3, 2, 5, 4 };
    for (0..8) |_| {
        while (try g.poll(0)) |ev| _ = u.feed(ev);
        _ = u.begin(0) orelse continue;
        if (u.window("main", &main, goome.win.move | goome.win.resize | goome.win.collapse)) {
            _ = u.tabs("tabs", &tabs, &tab);
            u.pushIndex(@intCast(tab));
            if (u.scrollBegin("page", 0)) {
                u.heading("Head");
                u.row(2);
                _ = u.button("One");
                _ = u.button("Two");
                u.tooltip("tip");
                _ = u.hovered();
                u.label("100% sure %s %d");
                u.labelFmt("{d} things", .{n});
                u.wrapped("some long text that wraps around a bit");
                u.separator();
                u.space(4);
                u.width(120);
                _ = u.toggle("Toggle", &on);
                _ = u.radio("Small", &mode, 0);
                u.sameLine();
                _ = u.radio("Big", &mode, 1);
                _ = u.slider("Vol", &vol, 0, 1, "%.2f");
                _ = u.sliderInt("N", &n, 0, 10);
                u.progress(vol, "half");
                u.progress(-1, null);
                _ = u.color("Color", &color);
                _ = u.input("Name", &name);
                _ = u.inputEx("Pass", &name, c.GOOME_INPUT_PASSWORD, "hint");
                if (u.collapsing("More", &more)) {
                    for (0..3) |k| _ = u.selectable(if (k == 1) "Item 1" else "Item", k == 1);
                }
                _ = u.collapsing("Self kept", null);
                u.image(&logo, 32, 32, 6);
                _ = u.imageButton("img", &logo, 24, 24);
                _ = u.textEdit("body", &body, 80, c.GOOME_EDIT_LINE_NUMBERS);
                _ = u.dragFloat("Drag", &vol, 0.01, 0, 1, null);
                _ = u.number("Num", &vol, 0.1, null);
                u.plotLines("lines", &plot, 0, 5, 40);
                u.plotBars("bars", &plot, 0, 5, 40);
                if (u.tableBegin("t", 2, 80, c.GOOME_TABLE_SORTABLE)) {
                    u.tableColumn("A", 0);
                    u.tableColumn("B", 0);
                    _ = u.tableSort(&col, &desc);
                    u.tableRow();
                    u.label("a");
                    u.tableNext();
                    u.label("b");
                }
                u.tableEnd();
                if (u.splitBegin("sp", false, &split)) {
                    u.label("left");
                    u.splitNext();
                    u.label("right");
                }
                u.splitEnd();
                if (u.tree("node", null)) {
                    u.label("leaf");
                    u.treeEnd();
                }
                _ = u.link("a link");
                u.badge("new", 0xFFFF4040);
                u.spinner(16);
                var it: goome.Item = .{};
                _ = u.custom("knob", 40, 40, c.GOOME_ITEM_DRAG_Y, &it);
                if (u.canvas()) |kc| kc.circle(it.x + 20, it.y + 20, 16, 0xFF6FDC5F);
                if (u.store("knob", 2)) |st| st[0] += 1;
                if (u.modalBegin("Modal", &modal_open)) {
                    u.label("modal");
                    u.modalEnd();
                }
            }
            u.scrollEnd();
            u.popId();
        }
        u.windowEnd();
        if (u.window("Stats", &stats, goome.win.move | goome.win.close)) u.label("stats");
        u.windowEnd();
        u.hit(0, 0, 4, 4);
        _ = u.animating();
        u.end();
    }
    try expect(stats.isOpen());
    stats.setOpen(false);
    _ = u.begin(0) orelse return error.NoCanvas;
    try expect(!u.window("Stats", &stats, goome.win.close));
    u.windowEnd();
    u.end();
}

fn labelHash(comptime plain: bool) !u32 {
    const g = try goome.Goome.open(.{ .backend = .@"test", .test_script = "screen 300x200 1; end 3" });
    defer g.deinit();
    const u = try g.ui();
    defer u.deinit();
    u.theme().font = null;
    var w: goome.Window = .{ .x = 10, .y = 10, .w = 200 };
    const cv = u.begin(0) orelse return error.NoCanvas;
    if (u.window("w", &w, 0)) {
        if (plain) c.goome_ui_label(u.raw(), "100%% sure %%s") else u.label("100% sure %s");
    }
    u.windowEnd();
    u.end();
    return fnv(cv.pixels(), cv.width(), cv.height(), cv.stride());
}

test "label is not a format string" {
    try expectEqual(try labelHash(true), try labelHash(false));
}

test "offscreen frames" {
    const g = try goome.Goome.openOffscreen(200, 100, 1);
    defer g.deinit();
    try expectEqual(goome.Mode.offscreen, g.mode());
    const u = try g.ui();
    defer u.deinit();
    var w: goome.Window = .{ .x = 10, .y = 10, .w = 150 };
    try g.pushClick(30, 30);
    while (try g.poll(0)) |ev| _ = u.feed(ev);
    _ = u.begin(0) orelse return error.NoCanvas;
    if (u.window("w", &w, 0)) _ = u.button("hi");
    u.windowEnd();
    u.end();
    const f = try g.frame();
    try expectEqual(@as(usize, 200), f.width());
    try expect(g.hit(30, 30));
    try expect(!g.hit(195, 95));
    const d = g.frameDirty() orelse return error.NoDirty;
    try expect(d.w > 0);
    const buf = try alloc.alloc(u8, 200 * 100 * 4);
    defer alloc.free(buf);
    try g.frameCopy(buf, 200 * 4, .rgba, null);
    try std.testing.expectError(error.BadArgument, g.frameCopy(buf[0..10], 200 * 4, .rgba, null));
    try g.resize(300, 150, 1);
}
