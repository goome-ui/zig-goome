const std = @import("std");
const goome = @import("goome");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const args = try std.process.argsAlloc(arena.allocator());
    if (args.len < 2) {
        std.debug.print("usage: grab [monitor] [x y w h] out.ppm\n", .{});
        std.process.exit(2);
    }
    var nums: [5]i32 = undefined;
    var nn: usize = 0;
    for (args[1 .. args.len - 1]) |a| {
        if (nn == 5) break;
        nums[nn] = std.fmt.parseInt(i32, a, 10) catch 0;
        nn += 1;
    }
    const g = goome.Goome.open(.{ .title = "goome grab" }) catch |e| {
        std.debug.print("cant open: {s}\n", .{goome.strerror(goome.errorCode(e))});
        std.process.exit(1);
    };
    defer g.deinit();
    const mon: i32 = if (nn == 1 or nn == 5) nums[0] else 0;
    const area: ?goome.Rect = if (nn >= 4) goome.rect(nums[nn - 4], nums[nn - 3], nums[nn - 2], nums[nn - 1]) else null;
    var tries: usize = 0;
    const img = while (true) : (tries += 1) {
        if (g.capture(mon, area)) |img| break img else |e| {
            if (e != error.Again or tries >= 50) {
                std.debug.print("grab failed: {s} ({s})\n", .{ goome.strerror(goome.errorCode(e)), g.lastError() });
                std.process.exit(1);
            }
            _ = g.poll(100) catch {};
        }
    };
    const path = args[args.len - 1];
    try img.savePpm(path);
    const r = img.raw;
    const out = std.fs.File.stdout().deprecatedWriter();
    try out.print("{d}x{d} px of {d},{d} {d}x{d} on monitor {d}{s}{s}\n", .{
        r.w,                                              r.h,                                               r.area.x, r.area.y, r.area.w, r.area.h, mon,
        if (r.has_self != 0) ", has our overlay" else "", if (r.has_cursor != 0) ", has the cursor" else "",
    });
}
