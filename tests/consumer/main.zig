const std = @import("std");
const goome = @import("goome");

pub fn main() !void {
    const g = try goome.Goome.openOffscreen(320, 200, 1);
    defer g.deinit();
    const u = try g.ui();
    defer u.deinit();
    var w: goome.Window = .{ .x = 10, .y = 10, .w = 200 };
    _ = u.begin(0) orelse return error.NoCanvas;
    if (u.window("hi", &w, 0)) u.label("from a package");
    u.windowEnd();
    u.end();
    const f = try g.frame();
    std.debug.print("goome {s}, frame {d}x{d}\n", .{ goome.version, f.width(), f.height() });
}
