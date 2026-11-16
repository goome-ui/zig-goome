const std = @import("std");
const goome = @import("goome");
const c = goome.c;

const lines = [_][*:0]const u8{
    "goome \u{1F600} \u{1F389} \u{1F44D}\u{1F3FD} \u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467} \u{1F1E9}\u{1F1EA} #\u{FE0F}\u{20E3} \u{2764}\u{FE0F} \u{1F431}",
    "\u{0627}\u{0644}\u{0633}\u{0644}\u{0627}\u{0645} \u{0639}\u{0644}\u{064A}\u{0643}\u{0645}\u{060C} \u{0643}\u{064A}\u{0641} \u{062D}\u{0627}\u{0644}\u{0643}\u{061F}",
    "\u{05E9}\u{05DC}\u{05D5}\u{05DD} \u{05E2}\u{05D5}\u{05DC}\u{05DD}, \u{05DE}\u{05D4} \u{05E9}\u{05DC}\u{05D5}\u{05DE}\u{05DA}?",
    "goome says \u{0645}\u{0631}\u{062D}\u{0628}\u{0627} (123) to \u{05E9}\u{05DC}\u{05D5}\u{05DD} \u{1F44B}",
    "\u{0644}\u{0627} \u{0644}\u{0623}\u{0646} \u{0645}\u{062D}\u{0645}\u{062F} \u{0643}\u{062A}\u{0628} 2024 [ok]",
};

const role_names = [_][]const u8{ "none", "window", "button", "checkbox", "radio", "slider", "text", "input", "combo", "list", "item", "tab", "menu", "menuitem", "table", "tree", "progress", "image", "group", "dialog" };

fn save(g: *goome.Goome, path: [*:0]const u8, allocator: std.mem.Allocator) !void {
    const f = try g.frame();
    const out = try allocator.alloc(u32, f.width() * f.height());
    defer allocator.free(out);
    for (0..f.height()) |y| {
        for (f.row(y), 0..) |s, x| {
            const a = s >> 24;
            var v: u32 = 0xFF000000;
            inline for (.{ 0, 8, 16 }) |k| v |= ((s >> k & 255) + (0x20 * (255 - a)) / 255) << k;
            out[y * f.width() + x] = v;
        }
    }
    try goome.savePpm(path, out, f.width(), f.height(), f.width());
}

fn printTree(u: *goome.Ui, allocator: std.mem.Allocator) !void {
    var tree = try u.a11yTree(allocator);
    defer tree.deinit();
    const out = std.fs.File.stdout().deprecatedWriter();
    for (tree.nodes) |n| {
        var depth: usize = 0;
        var p = n.parent;
        while (p) |i| : (p = tree.nodes[i].parent) depth += 1;
        const role: usize = @intCast(@intFromEnum(n.role));
        const name = if (role < role_names.len) role_names[role] else "?";
        try out.writeByteNTimes(' ', depth * 2);
        try out.print("{s} \"{s}\"", .{ name, n.label });
        if (n.value.len > 0) try out.print(" = \"{s}\"", .{n.value});
        if (n.has(goome.a11y.focused)) try out.writeAll(" (focused)");
        try out.writeByte('\n');
    }
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const shot: ?[:0]const u8 = if (args.len > 1) args[1] else null;
    const g = goome.Goome.open(.{
        .title = "goome text",
        .mode = if (shot != null) .offscreen else .window,
        .width = 560,
        .height = 600,
        .scale = if (shot != null) 2 else 0,
        .window_flags = goome.window_flags.resizable | goome.window_flags.center,
    }) catch |e| {
        std.debug.print("cant open: {s}\n", .{goome.strerror(goome.errorCode(e))});
        std.process.exit(1);
    };
    defer g.deinit();
    const u = try g.ui();
    defer u.deinit();
    if (shot != null) {
        u.theme().anim_ms = 0;
        u.config().blink_ms = 0;
        u.a11yOn(true);
    }
    var dir: i32 = @intFromEnum(goome.TextDir.auto);
    var run = true;
    var frame: usize = 0;
    var name: [128]u8 = undefined;
    goome.setText(&name, "\u{0627}\u{0644}\u{0639}\u{0631}\u{0628}\u{064A}\u{0629} abc \u{1F600}");
    var notes: [1024]u8 = undefined;
    goome.setText(&notes, "\u{05E9}\u{05DC}\u{05D5}\u{05DD}! this line starts in hebrew\nmixed: abc \u{0639}\u{0631}\u{0628}\u{064A} 42 \u{1F44D}\u{1F3FD}\n\u{0645}\u{0631}\u{062D}\u{0628}\u{0627} \u{0628}\u{0643}\u{0645}");
    while (run) {
        if (shot != null and frame == 3) {
            try g.push(.{ .kind = .key, .key = goome.key.end });
            for (0..6) |_| try g.push(.{ .kind = .key, .key = goome.key.right, .mods = goome.mod.shift });
        }
        while (try g.poll(if (shot != null) 0 else 16)) |ev| {
            if (ev.kind == .close or ev.kind == .quit) run = false;
            _ = u.feed(ev);
        }
        _ = u.begin(0) orelse continue;
        goome.textDir(@enumFromInt(dir));
        if (u.app("goome text", 0)) {
            u.heading("Emoji, Arabic, Hebrew");
            for (lines) |l| u.label(l);
            u.separator();
            u.row(3);
            _ = u.radio("Auto", &dir, @intFromEnum(goome.TextDir.auto));
            _ = u.radio("Left to right", &dir, @intFromEnum(goome.TextDir.ltr));
            _ = u.radio("Right to left", &dir, @intFromEnum(goome.TextDir.rtl));
            u.row(1);
            if (shot != null and frame == 2) u.setFocus();
            _ = u.input("Name", &name);
            _ = u.textEdit("notes", &notes, 120, c.GOOME_EDIT_WRAP);
        }
        u.appEnd();
        u.end();
        goome.textDir(.auto);
        if (shot != null) {
            frame += 1;
            if (frame == 6) run = false;
        }
    }
    if (shot) |path| {
        try save(g, path, allocator);
        try printTree(u, allocator);
    }
}
