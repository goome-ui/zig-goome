const std = @import("std");
const goome = @import("goome");

pub fn main() !void {
    const out = std.fs.File.stdout().deprecatedWriter();
    const g = goome.Goome.open(.{ .title = "goome hello" }) catch |e| {
        std.debug.print("cant open an overlay: {s}\n", .{goome.strerror(goome.errorCode(e))});
        std.process.exit(1);
    };
    defer g.deinit();
    var mons: [16]goome.Monitor = undefined;
    const ms = g.monitors(&mons);
    try out.print("backend: {s}\n", .{g.backendName()});
    for (ms, 0..) |m, i| {
        try out.print("monitor {d}: {s} {d}x{d} at {d},{d} scale {d:.2}\n", .{ i, std.mem.sliceTo(&m.name, 0), m.area.w, m.area.h, m.area.x, m.area.y, m.scale });
    }
    g.hotkey("alt+h", 1) catch try out.print("no global hotkeys here: {s}\n", .{g.lastError()});

    const area = if (ms.len > 0) ms[0].area else goome.rect(0, 0, 1280, 720);
    const bx: f64 = @floatFromInt(area.x + 80);
    var by: f64 = @floatFromInt(area.y + 80);
    var clicks: u32 = 0;
    var hidden = false;
    var typing = false;
    var running = true;
    var typed: [40]u8 = [_]u8{0} ** 40;
    var pace: goome.Pacer = .{};
    while (running) {
        var wait = pace.wait(30);
        while (try g.poll(wait)) |ev| {
            switch (ev.kind) {
                .quit => running = false,
                .down => {
                    try out.print("click {d:.0},{d:.0}\n", .{ ev.x, ev.y });
                    if (ev.x > bx + 250 and ev.y < by + 30) {
                        running = false;
                    } else if (ev.y > by + 80) {
                        typing = !typing;
                        g.keyboard(typing) catch {};
                    } else clicks += 1;
                },
                .key => {
                    try out.print("key {d} mods {x} text '{s}'\n", .{ ev.key, ev.mods, ev.typed() });
                    const now = goome.text(&typed);
                    if (ev.key == goome.key.esc) {
                        running = false;
                    } else if (ev.key == goome.key.backspace and now.len > 0) {
                        typed[now.len - 1] = 0;
                    } else if (ev.typed().len > 0) {
                        var both: [80]u8 = undefined;
                        const joined = std.fmt.bufPrint(&both, "{s}{s}", .{ now, ev.typed() }) catch now;
                        goome.setText(&typed, joined);
                    }
                },
                .hotkey => hidden = !hidden,
                .control => {
                    if (std.mem.eql(u8, ev.message(), "hide")) hidden = !hidden;
                },
                .scroll => by += @floatFromInt(ev.dy * 10),
                else => {},
            }
            wait = pace.wait(30);
        }
        const c = g.begin(0) orelse continue;
        const hit = goome.rect(@intFromFloat(bx), @intFromFloat(by), 280, 120);
        if (!hidden) {
            c.roundRect(bx, by, 280, 120, 14, 0xE0202838);
            c.frame(bx, by, 280, 120, 2, if (clicks & 1 != 0) 0xFF6FDC5F else 0xFF8090A0);
            _ = c.text(bx + 16, by + 12, "hello from goome", true, 0xFFFFFFFF);
            c.line(bx + 256, by + 10, bx + 268, by + 22, 2, 0xFFFF6B8B);
            c.line(bx + 268, by + 10, bx + 256, by + 22, 2, 0xFFFF6B8B);
            var line: [64]u8 = undefined;
            _ = c.text(bx + 16, by + 46, try std.fmt.bufPrintZ(&line, "clicks: {d}", .{clicks}), false, 0xFFC0C8D0);
            c.roundRect(bx + 12, by + 80, 256, 28, 8, if (typing) 0xFF2E4A30 else 0xFF303848);
            const shown: [*:0]const u8 = if (!typing) "click here to type" else if (typed[0] != 0) @ptrCast(&typed) else "type something...";
            _ = c.text(bx + 22, by + 86, shown, false, 0xFFFFFFFF);
        }
        try g.end(c, if (hidden) &.{} else &.{hit});
    }
}
