const std = @import("std");

pub const c = @cImport({
    @cInclude("goome.h");
});

pub const version: []const u8 = c.GOOME_VERSION;

pub const Error = error{
    NotSupported,
    Denied,
    NoDisplay,
    Gone,
    Again,
    OutOfMemory,
    BadArgument,
    LoadFailed,
    Unknown,
};

pub fn toError(code: c_int) Error {
    return switch (code) {
        c.GOOME_ENOTSUP => error.NotSupported,
        c.GOOME_EDENIED => error.Denied,
        c.GOOME_ENODISPLAY => error.NoDisplay,
        c.GOOME_EGONE => error.Gone,
        c.GOOME_EAGAIN => error.Again,
        c.GOOME_ENOMEM => error.OutOfMemory,
        c.GOOME_EARG => error.BadArgument,
        else => error.Unknown,
    };
}

pub fn errorCode(e: Error) c_int {
    return switch (e) {
        error.NotSupported => c.GOOME_ENOTSUP,
        error.Denied => c.GOOME_EDENIED,
        error.NoDisplay => c.GOOME_ENODISPLAY,
        error.Gone => c.GOOME_EGONE,
        error.Again => c.GOOME_EAGAIN,
        error.OutOfMemory => c.GOOME_ENOMEM,
        error.BadArgument, error.LoadFailed, error.Unknown => c.GOOME_EARG,
    };
}

fn check(rc: c_int) Error!void {
    if (rc < 0) return toError(rc);
}

fn checkN(rc: c_int) Error!usize {
    if (rc < 0) return toError(rc);
    return @intCast(rc);
}

pub fn strerror(code: c_int) [:0]const u8 {
    return std.mem.span(c.goome_strerror(code));
}

fn span(p: [*c]const u8) ?[:0]const u8 {
    if (p == null) return null;
    return std.mem.span(@as([*:0]const u8, @ptrCast(p)));
}

fn cstr(s: ?[*:0]const u8) [*c]const u8 {
    return if (s) |p| p else null;
}

fn cb(v: bool) c_int {
    return @intFromBool(v);
}

pub const Rect = c.goome_rect;
pub const Monitor = c.goome_monitor;
pub const Radii = c.goome_radii;
pub const Theme = c.goome_theme;
pub const Skin = c.goome_skin;
pub const Item = c.goome_ui_item;
pub const UiConfig = c.goome_ui_config;
pub const KeyCombo = c.goome_combo;

pub fn rect(x: c_int, y: c_int, w: c_int, h: c_int) Rect {
    return .{ .x = x, .y = y, .w = w, .h = h };
}

pub fn radius(r: f64) Radii {
    return c.goome_radius(r);
}

pub fn corners(tl: f64, tr: f64, br: f64, bl: f64) Radii {
    return .{ .tl = tl, .tr = tr, .br = br, .bl = bl };
}

pub const Backend = enum(c_int) {
    auto = c.GOOME_AUTO,
    wayland = c.GOOME_WAYLAND,
    gnome = c.GOOME_GNOME,
    portal = c.GOOME_PORTAL,
    x11 = c.GOOME_X11,
    win32 = c.GOOME_WIN32,
    macos = c.GOOME_MACOS,
    @"test" = c.GOOME_TEST,
    offscreen = c.GOOME_OFFSCREEN,
};

pub const Mode = enum(c_int) {
    overlay = c.GOOME_MODE_OVERLAY,
    window = c.GOOME_MODE_WINDOW,
    offscreen = c.GOOME_MODE_OFFSCREEN,
    _,
};

pub const EventType = enum(c_int) {
    none = c.GOOME_NONE,
    down = c.GOOME_DOWN,
    up = c.GOOME_UP,
    motion = c.GOOME_MOTION,
    scroll = c.GOOME_SCROLL,
    key = c.GOOME_KEY,
    hotkey = c.GOOME_HOTKEY,
    control = c.GOOME_CONTROL,
    monitors = c.GOOME_MONITORS,
    quit = c.GOOME_QUIT,
    close = c.GOOME_CLOSE,
    focus = c.GOOME_FOCUS,
    drop = c.GOOME_DROP,
    text = c.GOOME_TEXT,
    preedit = c.GOOME_PREEDIT,
    _,
};

pub const Event = extern struct {
    kind: EventType = .none,
    x: f64 = 0,
    y: f64 = 0,
    mon: c_int = 0,
    button: c_int = 0,
    dy: c_int = 0,
    key: c_int = 0,
    mods: c_int = 0,
    text: [8]u8 = [_]u8{0} ** 8,
    id: c_int = 0,
    msg: [64]u8 = [_]u8{0} ** 64,

    pub fn typed(e: *const Event) []const u8 {
        return std.mem.sliceTo(&e.text, 0);
    }

    pub fn message(e: *const Event) []const u8 {
        return std.mem.sliceTo(&e.msg, 0);
    }

    pub fn raw(e: *const Event) *const c.goome_event {
        return @ptrCast(e);
    }
};

pub const key = struct {
    pub const backspace = c.GOOME_K_BACKSPACE;
    pub const tab = c.GOOME_K_TAB;
    pub const enter = c.GOOME_K_ENTER;
    pub const esc = c.GOOME_K_ESC;
    pub const space = c.GOOME_K_SPACE;
    pub const delete = c.GOOME_K_DELETE;
    pub const f1 = c.GOOME_K_F1;
    pub const f12 = c.GOOME_K_F12;
    pub const left = c.GOOME_K_LEFT;
    pub const right = c.GOOME_K_RIGHT;
    pub const up = c.GOOME_K_UP;
    pub const down = c.GOOME_K_DOWN;
    pub const home = c.GOOME_K_HOME;
    pub const end = c.GOOME_K_END;
    pub const pgup = c.GOOME_K_PGUP;
    pub const pgdn = c.GOOME_K_PGDN;
    pub const insert = c.GOOME_K_INSERT;
};

pub const mod = struct {
    pub const shift = c.GOOME_SHIFT;
    pub const ctrl = c.GOOME_CTRL;
    pub const alt = c.GOOME_ALT;
    pub const super = c.GOOME_SUPER;
};

pub const cap = struct {
    pub const capture = c.GOOME_CAP_CAPTURE;
    pub const global_pointer = c.GOOME_CAP_GLOBAL_POINTER;
    pub const hotkeys = c.GOOME_CAP_HOTKEYS;
    pub const hide_self = c.GOOME_CAP_HIDE_SELF;
    pub const keyboard = c.GOOME_CAP_KEYBOARD;
    pub const window = c.GOOME_CAP_WINDOW;
    pub const clipboard = c.GOOME_CAP_CLIPBOARD;
    pub const cursor = c.GOOME_CAP_CURSOR;
    pub const grab = c.GOOME_CAP_GRAB;
};

pub const window_flags = struct {
    pub const resizable = c.GOOME_WINDOW_RESIZABLE;
    pub const borderless = c.GOOME_WINDOW_BORDERLESS;
    pub const transparent = c.GOOME_WINDOW_TRANSPARENT;
    pub const on_top = c.GOOME_WINDOW_ON_TOP;
    pub const hidden = c.GOOME_WINDOW_HIDDEN;
    pub const center = c.GOOME_WINDOW_CENTER;
    pub const no_titlebar = c.GOOME_WINDOW_NO_TITLEBAR;
};

pub const win = struct {
    pub const move = c.GOOME_WIN_MOVE;
    pub const resize = c.GOOME_WIN_RESIZE;
    pub const collapse = c.GOOME_WIN_COLLAPSE;
    pub const no_title = c.GOOME_WIN_NO_TITLE;
    pub const close = c.GOOME_WIN_CLOSE;
};

pub const want = struct {
    pub const mouse = c.GOOME_WANT_MOUSE;
    pub const keyboard = c.GOOME_WANT_KEYBOARD;
};

pub const Ease = enum(c_int) {
    smooth = c.GOOME_EASE_SMOOTH,
    linear = c.GOOME_EASE_LINEAR,
    out = c.GOOME_EASE_OUT,
    in_out = c.GOOME_EASE_IN_OUT,
    back = c.GOOME_EASE_BACK,
    custom = c.GOOME_EASE_CUSTOM,
    in = c.GOOME_EASE_IN,
    spring = c.GOOME_EASE_SPRING,
    bounce = c.GOOME_EASE_BOUNCE,
    _,
};

pub fn ease(e: Ease, t: f64) f64 {
    return c.goome_ease(@intFromEnum(e), t);
}

pub const TextDir = enum(c_int) {
    auto = c.GOOME_DIR_AUTO,
    ltr = c.GOOME_DIR_LTR,
    rtl = c.GOOME_DIR_RTL,
};

pub fn textDir(dir: TextDir) void {
    c.goome_text_dir(@intFromEnum(dir));
}

pub const Role = enum(c_int) {
    none = c.GOOME_ROLE_NONE,
    window = c.GOOME_ROLE_WINDOW,
    button = c.GOOME_ROLE_BUTTON,
    checkbox = c.GOOME_ROLE_CHECKBOX,
    radio = c.GOOME_ROLE_RADIO,
    slider = c.GOOME_ROLE_SLIDER,
    text = c.GOOME_ROLE_TEXT,
    input = c.GOOME_ROLE_INPUT,
    combo = c.GOOME_ROLE_COMBO,
    list = c.GOOME_ROLE_LIST,
    item = c.GOOME_ROLE_ITEM,
    tab = c.GOOME_ROLE_TAB,
    menu = c.GOOME_ROLE_MENU,
    menuitem = c.GOOME_ROLE_MENUITEM,
    table = c.GOOME_ROLE_TABLE,
    tree = c.GOOME_ROLE_TREE,
    progress = c.GOOME_ROLE_PROGRESS,
    image = c.GOOME_ROLE_IMAGE,
    group = c.GOOME_ROLE_GROUP,
    dialog = c.GOOME_ROLE_DIALOG,
    _,
};

pub const a11y = struct {
    pub const focused = c.GOOME_A11Y_FOCUSED;
    pub const checked = c.GOOME_A11Y_CHECKED;
    pub const disabled = c.GOOME_A11Y_DISABLED;
    pub const expanded = c.GOOME_A11Y_EXPANDED;
    pub const selected = c.GOOME_A11Y_SELECTED;
};

pub const RawA11yNode = c.goome_a11y_node;

pub const A11yNode = struct {
    role: Role,
    parent: ?usize,
    states: c_int,
    x: f64,
    y: f64,
    w: f64,
    h: f64,
    label: []const u8,
    value: []const u8,
    id: u32,
    num: f64,
    min: f64,
    max: f64,
    caret: i32,

    pub fn has(n: A11yNode, st: c_int) bool {
        return n.states & st != 0;
    }
};

pub const A11yTree = struct {
    raw: []RawA11yNode,
    nodes: []A11yNode,
    allocator: std.mem.Allocator,

    pub fn deinit(t: *A11yTree) void {
        t.allocator.free(t.nodes);
        t.allocator.free(t.raw);
        t.raw = &.{};
        t.nodes = &.{};
    }

    pub fn find(t: A11yTree, role: Role, label: []const u8) ?usize {
        for (t.nodes, 0..) |n, i| {
            if (n.role == role and std.mem.eql(u8, n.label, label)) return i;
        }
        return null;
    }
};

pub const Format = enum(c_int) {
    bgra_premul = c.GOOME_FMT_BGRA_PREMUL,
    rgba_premul = c.GOOME_FMT_RGBA_PREMUL,
    bgra = c.GOOME_FMT_BGRA,
    rgba = c.GOOME_FMT_RGBA,
};

pub const Options = struct {
    title: ?[*:0]const u8 = null,
    backend: Backend = .auto,
    state_dir: ?[*:0]const u8 = null,
    no_capture: bool = false,
    capture_fps: i32 = 0,
    hide_self: bool = false,
    test_frames: ?[*:0]const u8 = null,
    test_script: ?[*:0]const u8 = null,
    test_shots: ?[*:0]const u8 = null,
    mode: Mode = .overlay,
    width: i32 = 0,
    height: i32 = 0,
    min_width: i32 = 0,
    min_height: i32 = 0,
    window_flags: c_int = 0,
    scale: f64 = 0,

    pub fn toC(o: Options) c.goome_opts {
        return .{
            .title = cstr(o.title),
            .backend = @intFromEnum(o.backend),
            .state_dir = cstr(o.state_dir),
            .no_capture = cb(o.no_capture),
            .capture_fps = o.capture_fps,
            .hide_self = cb(o.hide_self),
            .test_frames = cstr(o.test_frames),
            .test_script = cstr(o.test_script),
            .test_shots = cstr(o.test_shots),
            .mode = @intFromEnum(o.mode),
            .width = o.width,
            .height = o.height,
            .min_width = o.min_width,
            .min_height = o.min_height,
            .window_flags = o.window_flags,
            .scale = o.scale,
        };
    }
};

pub const Combo = struct { key: c_int, mods: c_int };

pub fn parseCombo(combo: [*:0]const u8) Error!Combo {
    var k: c_int = 0;
    var m: c_int = 0;
    try check(c.goome_parse_combo(combo, &k, &m));
    return .{ .key = k, .mods = m };
}

pub fn send(state_dir: [*:0]const u8, msg: [*:0]const u8) Error!void {
    try check(c.goome_send(state_dir, msg));
}

pub fn nowMs() i64 {
    return @intCast(c.goome_now_ms());
}

pub fn savePpm(path: [*:0]const u8, px: []const u32, w: usize, h: usize, stride: usize) Error!void {
    if (h > 0 and px.len < (h - 1) * stride + w) return error.BadArgument;
    try check(c.goome_save_ppm(path, px.ptr, @intCast(w), @intCast(h), @intCast(stride)));
}

pub const Pacer = struct {
    raw: c.goome_pacer = .{},

    pub fn wait(p: *Pacer, fps: i32) i32 {
        return c.goome_pace(&p.raw, fps);
    }
};

pub const Image = struct {
    raw: c.goome_image,

    pub fn width(img: Image) usize {
        return @intCast(img.raw.w);
    }

    pub fn height(img: Image) usize {
        return @intCast(img.raw.h);
    }

    pub fn stride(img: Image) usize {
        return @intCast(img.raw.stride);
    }

    pub fn pixels(img: Image) []u32 {
        if (img.raw.px == null) return &.{};
        return img.raw.px[0 .. img.height() * img.stride()];
    }

    pub fn row(img: Image, y: usize) []u32 {
        return img.pixels()[y * img.stride() ..][0..img.width()];
    }

    pub fn pixel(img: Image, x: usize, y: usize) u32 {
        return img.pixels()[y * img.stride() + x];
    }

    pub fn savePpm(img: Image, path: [*:0]const u8) Error!void {
        try savePpmRaw(path, img.raw.px, img.raw.w, img.raw.h, img.raw.stride);
    }
};

fn savePpmRaw(path: [*:0]const u8, px: [*c]const u32, w: c_int, h: c_int, stride: c_int) Error!void {
    try check(c.goome_save_ppm(path, px, w, h, stride));
}

pub const Pointer = struct { x: f64, y: f64, buttons: c_int };

pub const Goome = opaque {
    fn raw(g: *Goome) *c.goome {
        return @ptrCast(g);
    }

    pub fn open(o: Options) Error!*Goome {
        var err: c_int = 0;
        const opts = o.toC();
        const g = c.goome_open(&opts, &err) orelse return toError(if (err < 0) err else c.GOOME_ENODISPLAY);
        return @ptrCast(g);
    }

    pub fn openApp(title: [*:0]const u8, w: i32, h: i32) Error!*Goome {
        var err: c_int = 0;
        const g = c.goome_open_app(title, w, h, &err) orelse return toError(if (err < 0) err else c.GOOME_ENODISPLAY);
        return @ptrCast(g);
    }

    pub fn openOffscreen(w: i32, h: i32, scale: f64) Error!*Goome {
        return open(.{ .mode = .offscreen, .width = w, .height = h, .scale = scale });
    }

    pub fn deinit(g: *Goome) void {
        c.goome_close(g.raw());
    }

    pub fn lastError(g: *Goome) [:0]const u8 {
        return span(c.goome_error(g.raw())) orelse "";
    }

    pub fn backendName(g: *Goome) [:0]const u8 {
        return span(c.goome_backend_name(g.raw())) orelse "";
    }

    pub fn caps(g: *Goome) c_int {
        return c.goome_caps(g.raw());
    }

    pub fn can(g: *Goome, what: c_int) bool {
        return g.caps() & what != 0;
    }

    pub fn mode(g: *Goome) Mode {
        return @enumFromInt(c.goome_mode(g.raw()));
    }

    pub fn monitors(g: *Goome, buf: []Monitor) []Monitor {
        const n = c.goome_monitors(g.raw(), buf.ptr, @intCast(buf.len));
        if (n <= 0) return buf[0..0];
        return buf[0..@min(buf.len, @as(usize, @intCast(n)))];
    }

    pub fn capture(g: *Goome, mon: i32, area: ?Rect) Error!Image {
        var img: c.goome_image = .{};
        const r: [*c]const Rect = if (area) |*a| a else null;
        try check(c.goome_capture(g.raw(), mon, r, &img));
        return .{ .raw = img };
    }

    pub fn alphaAt(g: *Goome, x: f64, y: f64) u8 {
        const a = c.goome_alpha_at(g.raw(), x, y);
        return if (a < 0) 0 else @intCast(a);
    }

    pub fn begin(g: *Goome, mon: i32) ?*Canvas {
        const cv = c.goome_begin(g.raw(), mon);
        if (cv == null) return null;
        return @ptrCast(cv);
    }

    pub fn end(g: *Goome, cv: *Canvas, hits: []const Rect) Error!void {
        try check(c.goome_end(g.raw(), cv.raw(), hits.ptr, @intCast(hits.len)));
    }

    pub fn poll(g: *Goome, timeout_ms: i32) Error!?Event {
        var ev: Event = .{};
        const n = c.goome_poll(g.raw(), @ptrCast(&ev), timeout_ms);
        if (n < 0) return toError(n);
        if (n == 0) return null;
        return ev;
    }

    pub fn pointer(g: *Goome) ?Pointer {
        var p: Pointer = .{ .x = 0, .y = 0, .buttons = 0 };
        if (c.goome_pointer(g.raw(), &p.x, &p.y, &p.buttons) < 0) return null;
        return p;
    }

    pub fn keyboard(g: *Goome, on: bool) Error!void {
        try check(c.goome_keyboard(g.raw(), cb(on)));
    }

    pub fn grab(g: *Goome, on: bool) Error!void {
        try check(c.goome_grab(g.raw(), cb(on)));
    }

    pub fn grabbed(g: *Goome) bool {
        return c.goome_grabbed(g.raw()) > 0;
    }

    pub fn hotkey(g: *Goome, combo: [*:0]const u8, id: i32) Error!void {
        try check(c.goome_hotkey(g.raw(), combo, id));
    }

    pub fn controlPath(g: *Goome) ?[:0]const u8 {
        return span(c.goome_control_path(g.raw()));
    }

    pub fn setTitle(g: *Goome, title: [*:0]const u8) Error!void {
        try check(c.goome_window_title(g.raw(), title));
    }

    pub fn setSize(g: *Goome, w: i32, h: i32) Error!void {
        try check(c.goome_window_size(g.raw(), w, h));
    }

    pub fn position(g: *Goome) Error![2]i32 {
        var x: c_int = 0;
        var y: c_int = 0;
        try check(c.goome_window_pos(g.raw(), &x, &y, 0));
        return .{ x, y };
    }

    pub fn setPosition(g: *Goome, x: i32, y: i32) Error!void {
        var xx: c_int = x;
        var yy: c_int = y;
        try check(c.goome_window_pos(g.raw(), &xx, &yy, 1));
    }

    pub fn setState(g: *Goome, st: c_int) Error!void {
        try check(c.goome_window_state(g.raw(), st));
    }

    pub fn state(g: *Goome) c_int {
        return c.goome_window_get_state(g.raw());
    }

    pub fn drag(g: *Goome, edges: c_int) Error!void {
        try check(c.goome_window_drag(g.raw(), edges));
    }

    pub fn show(g: *Goome, on: bool) Error!void {
        try check(c.goome_window_show(g.raw(), cb(on)));
    }

    pub fn setCursor(g: *Goome, shape: c_int) Error!void {
        try check(c.goome_cursor(g.raw(), shape));
    }

    pub fn cursor(g: *Goome) c_int {
        return c.goome_cursor_shape(g.raw());
    }

    pub fn setClipboard(g: *Goome, utf8: [*:0]const u8) Error!void {
        try check(c.goome_clipboard_set(g.raw(), utf8));
    }

    pub fn clipboard(g: *Goome, buf: []u8) Error![]u8 {
        if (buf.len == 0) return error.BadArgument;
        const n = try checkN(c.goome_clipboard_get(g.raw(), buf.ptr, @intCast(buf.len)));
        return buf[0..@min(n, buf.len - 1)];
    }

    pub fn dropPath(g: *Goome) ?[:0]const u8 {
        return span(c.goome_drop_path(g.raw()));
    }

    pub fn eventText(g: *Goome) [:0]const u8 {
        return span(c.goome_event_text(g.raw())) orelse "";
    }

    pub fn preeditCursor(g: *Goome) usize {
        return @intCast(@max(0, c.goome_preedit_cursor(g.raw())));
    }

    pub fn textInput(g: *Goome, on: bool, caret: ?Rect) Error!void {
        const r: [*c]const Rect = if (caret) |*a| a else null;
        try check(c.goome_text_input(g.raw(), cb(on), r));
    }

    pub fn push(g: *Goome, ev: Event) Error!void {
        try check(c.goome_push(g.raw(), ev.raw()));
    }

    pub fn pushClick(g: *Goome, x: f64, y: f64) Error!void {
        try g.push(.{ .kind = .down, .x = x, .y = y, .button = 1 });
        try g.push(.{ .kind = .up, .x = x, .y = y, .button = 1 });
    }

    pub fn resize(g: *Goome, w: i32, h: i32, scale: f64) Error!void {
        try check(c.goome_resize(g.raw(), w, h, scale));
    }

    pub fn frame(g: *Goome) Error!Image {
        var img: c.goome_image = .{};
        try check(c.goome_frame(g.raw(), &img));
        return .{ .raw = img };
    }

    pub fn hit(g: *Goome, x: f64, y: f64) bool {
        return c.goome_hit(g.raw(), x, y) > 0;
    }

    pub fn frameDirty(g: *Goome) ?Rect {
        var r: Rect = .{};
        if (c.goome_frame_dirty(g.raw(), &r) <= 0) return null;
        return r;
    }

    pub fn frameCopy(g: *Goome, dst: []u8, dst_stride: usize, format: Format, area: ?Rect) Error!void {
        const fr = try g.frame();
        const w: usize = if (area) |a| @intCast(a.w) else fr.width();
        const h: usize = if (area) |a| @intCast(a.h) else fr.height();
        if (h > 0 and dst.len < (h - 1) * dst_stride + w * 4) return error.BadArgument;
        const r: [*c]const Rect = if (area) |*a| a else null;
        try check(c.goome_frame_copy(g.raw(), dst.ptr, @intCast(dst_stride), @intFromEnum(format), r));
    }

    pub fn ui(g: *Goome) Error!*Ui {
        const u = c.goome_ui_new(g.raw()) orelse return error.OutOfMemory;
        return @ptrCast(u);
    }
};

pub const Canvas = opaque {
    pub fn raw(cv: *Canvas) *c.goome_canvas {
        return @ptrCast(@alignCast(cv));
    }

    pub fn width(cv: *Canvas) usize {
        return @intCast(cv.raw().w);
    }

    pub fn height(cv: *Canvas) usize {
        return @intCast(cv.raw().h);
    }

    pub fn stride(cv: *Canvas) usize {
        return @intCast(cv.raw().stride);
    }

    pub fn scale(cv: *Canvas) f64 {
        return cv.raw().scale;
    }

    pub fn pixels(cv: *Canvas) []u32 {
        const r = cv.raw();
        if (r.px == null) return &.{};
        return r.px[0 .. cv.height() * cv.stride()];
    }

    pub fn damage(cv: *Canvas, r: ?Rect) void {
        const p: [*c]const Rect = if (r) |*a| a else null;
        c.goome_damage(cv.raw(), p);
    }

    pub fn clear(cv: *Canvas) void {
        c.goome_clear(cv.raw());
    }

    pub fn rect(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, argb: u32) void {
        c.goome_draw_rect(cv.raw(), x, y, w, h, argb);
    }

    pub fn roundRect(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, r: f64, argb: u32) void {
        c.goome_draw_round_rect(cv.raw(), x, y, w, h, r, argb);
    }

    pub fn frame(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, line_w: f64, argb: u32) void {
        c.goome_draw_frame(cv.raw(), x, y, w, h, line_w, argb);
    }

    pub fn line(cv: *Canvas, x0: f64, y0: f64, x1: f64, y1: f64, line_w: f64, argb: u32) void {
        c.goome_draw_line(cv.raw(), x0, y0, x1, y1, line_w, argb);
    }

    pub fn triangle(cv: *Canvas, x0: f64, y0: f64, x1: f64, y1: f64, x2: f64, y2: f64, argb: u32) void {
        c.goome_draw_triangle(cv.raw(), x0, y0, x1, y1, x2, y2, argb);
    }

    pub fn image(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, px: []const u32, iw: usize, ih: usize) void {
        if (px.len < iw * ih) return;
        c.goome_draw_image(cv.raw(), x, y, w, h, px.ptr, @intCast(iw), @intCast(ih));
    }

    pub fn erase(cv: *Canvas, x: f64, y: f64, w: f64, h: f64) void {
        c.goome_erase(cv.raw(), x, y, w, h);
    }

    pub fn text(cv: *Canvas, x: f64, y: f64, s: [*:0]const u8, big: bool, argb: u32) f64 {
        return c.goome_draw_text(cv.raw(), x, y, s, cb(big), argb);
    }

    pub fn textWidth(cv: *Canvas, s: [*:0]const u8, big: bool) f64 {
        return c.goome_text_width(cv.raw(), s, cb(big));
    }

    pub fn blit(cv: *Canvas, src: *Canvas, alpha: f64, dx: f64, dy: f64) void {
        c.goome_canvas_blit(cv.raw(), src.raw(), alpha, dx, dy);
    }

    pub fn clipPush(cv: *Canvas, x: f64, y: f64, w: f64, h: f64) void {
        c.goome_clip_push(cv.raw(), x, y, w, h);
    }

    pub fn clipPop(cv: *Canvas) void {
        c.goome_clip_pop(cv.raw());
    }

    pub fn rrect(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, r: Radii, argb: u32) void {
        c.goome_draw_rrect(cv.raw(), x, y, w, h, r, argb);
    }

    pub fn rrectLine(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, r: Radii, line_w: f64, argb: u32) void {
        c.goome_draw_rrect_line(cv.raw(), x, y, w, h, r, line_w, argb);
    }

    pub fn rrectGrad(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, r: Radii, from: u32, to: u32, sideways: bool) void {
        c.goome_draw_rrect_grad(cv.raw(), x, y, w, h, r, from, to, cb(sideways));
    }

    pub fn shadow(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, r: f64, blur: f64, argb: u32) void {
        c.goome_draw_shadow(cv.raw(), x, y, w, h, r, blur, argb);
    }

    pub fn circle(cv: *Canvas, cx: f64, cy: f64, r: f64, argb: u32) void {
        c.goome_draw_circle(cv.raw(), cx, cy, r, argb);
    }

    pub fn ring(cv: *Canvas, cx: f64, cy: f64, r: f64, line_w: f64, argb: u32) void {
        c.goome_draw_ring(cv.raw(), cx, cy, r, line_w, argb);
    }

    pub fn arc(cv: *Canvas, cx: f64, cy: f64, r: f64, line_w: f64, a0: f64, a1: f64, argb: u32) void {
        c.goome_draw_arc(cv.raw(), cx, cy, r, line_w, a0, a1, argb);
    }

    pub fn poly(cv: *Canvas, points: []const [2]f64, argb: u32) void {
        c.goome_draw_poly(cv.raw(), @ptrCast(points.ptr), @intCast(points.len), argb);
    }

    pub fn bitmap(cv: *Canvas, b: *const Bitmap, x: f64, y: f64, w: f64, h: f64, r: Radii, tint: u32) void {
        c.goome_draw_bitmap(cv.raw(), &b.raw, x, y, w, h, r, tint);
    }

    pub fn bitmapPart(cv: *Canvas, b: *const Bitmap, sx: i32, sy: i32, sw: i32, sh: i32, x: f64, y: f64, w: f64, h: f64, tint: u32) void {
        c.goome_draw_bitmap_part(cv.raw(), &b.raw, sx, sy, sw, sh, x, y, w, h, tint);
    }

    pub fn bitmapNine(cv: *Canvas, b: *const Bitmap, x: f64, y: f64, w: f64, h: f64, l: f64, t: f64, r: f64, bm: f64) void {
        c.goome_draw_bitmap_nine(cv.raw(), &b.raw, x, y, w, h, l, t, r, bm);
    }

    pub fn fontText(cv: *Canvas, f: ?*Font, size: f64, x: f64, y: f64, s: [*:0]const u8, argb: u32) f64 {
        return c.goome_text(cv.raw(), Font.ptr(f), size, x, y, s, argb);
    }
};

pub const OwnedCanvas = struct {
    raw: c.goome_canvas,
    buf: []u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, w: usize, h: usize, row_stride: usize, scale: f64) !OwnedCanvas {
        if (row_stride < w) return error.BadArgument;
        const buf = try allocator.alloc(u32, @max(1, h * row_stride));
        @memset(buf, 0);
        var cv: c.goome_canvas = std.mem.zeroes(c.goome_canvas);
        cv.px = buf.ptr;
        cv.w = @intCast(w);
        cv.h = @intCast(h);
        cv.stride = @intCast(row_stride);
        cv.scale = scale;
        return .{ .raw = cv, .buf = buf, .allocator = allocator };
    }

    pub fn deinit(o: *OwnedCanvas) void {
        o.allocator.free(o.buf);
        o.buf = &.{};
        o.raw.px = null;
    }

    pub fn canvas(o: *OwnedCanvas) *Canvas {
        return @ptrCast(&o.raw);
    }
};

pub fn bitmapError() [:0]const u8 {
    return span(c.goome_bitmap_error()) orelse "";
}

pub const Bitmap = struct {
    raw: c.goome_bitmap = .{},

    pub fn load(path: [*:0]const u8) Error!Bitmap {
        var b: Bitmap = .{};
        try check(c.goome_bitmap_load(path, &b.raw));
        return b;
    }

    pub fn loadMem(data: []const u8) Error!Bitmap {
        var b: Bitmap = .{};
        try check(c.goome_bitmap_load_mem(data.ptr, data.len, &b.raw));
        return b;
    }

    pub fn fromArgb(argb: []const u32, w: usize, h: usize) Error!Bitmap {
        if (argb.len < w * h) return error.BadArgument;
        var b: Bitmap = .{};
        try check(c.goome_bitmap_from_argb(argb.ptr, @intCast(w), @intCast(h), &b.raw));
        return b;
    }

    pub fn wrap(px: []u32, w: usize, h: usize, row_stride: usize) Bitmap {
        return .{ .raw = .{ .px = px.ptr, .w = @intCast(w), .h = @intCast(h), .stride = @intCast(row_stride), .owned = 0 } };
    }

    pub fn deinit(b: *Bitmap) void {
        c.goome_bitmap_free(&b.raw);
        b.raw = .{};
    }

    pub fn width(b: Bitmap) usize {
        return @intCast(b.raw.w);
    }

    pub fn height(b: Bitmap) usize {
        return @intCast(b.raw.h);
    }

    pub fn stride(b: Bitmap) usize {
        return @intCast(b.raw.stride);
    }

    pub fn owned(b: Bitmap) bool {
        return b.raw.owned != 0;
    }

    pub fn pixels(b: Bitmap) []u32 {
        if (b.raw.px == null) return &.{};
        return b.raw.px[0 .. b.height() * b.stride()];
    }
};

pub fn setFont(font: i32) void {
    c.goome_set_font(font);
}

pub fn fontCount() i32 {
    return c.goome_font_count();
}

pub const Size = struct { w: f64, h: f64 };

pub fn measure(size: f64, s: [*:0]const u8) Size {
    return Font.measureWith(null, size, s);
}

pub fn lineHeight(size: f64) f64 {
    return c.goome_text_line_height(null, size);
}

pub const Font = opaque {
    fn ptr(f: ?*Font) ?*c.goome_font {
        return @ptrCast(f);
    }

    fn wrapPtr(p: ?*c.goome_font) Error!*Font {
        return @ptrCast(p orelse return error.LoadFailed);
    }

    pub fn load(path: [*:0]const u8) Error!*Font {
        return wrapPtr(c.goome_font_load(path));
    }

    pub fn loadIndex(path: [*:0]const u8, index: i32) Error!*Font {
        return wrapPtr(c.goome_font_load_index(path, index));
    }

    pub fn loadMem(data: []const u8, copy: bool) Error!*Font {
        return wrapPtr(c.goome_font_load_mem(data.ptr, data.len, cb(copy)));
    }

    pub fn system(name: ?[*:0]const u8) ?*Font {
        return @ptrCast(c.goome_font_system(cstr(name)));
    }

    pub fn deinit(f: *Font) void {
        c.goome_font_free(ptr(f));
    }

    fn measureWith(f: ?*Font, size: f64, s: [*:0]const u8) Size {
        var h: f64 = 0;
        const w = c.goome_text_measure(ptr(f), size, s, &h);
        return .{ .w = w, .h = h };
    }

    pub fn measure(f: *Font, size: f64, s: [*:0]const u8) Size {
        return measureWith(f, size, s);
    }

    pub fn width(f: *Font, size: f64, s: [*:0]const u8) f64 {
        return measureWith(f, size, s).w;
    }

    pub fn lineHeight(f: *Font, size: f64) f64 {
        return c.goome_text_line_height(ptr(f), size);
    }

    pub fn fallback(f: *Font, other: *Font) void {
        c.goome_font_fallback(ptr(f), ptr(other));
    }
};

pub const Window = extern struct {
    x: f64 = 40,
    y: f64 = 40,
    w: f64 = 300,
    h: f64 = 0,
    open: c_int = 1,

    pub fn isOpen(w: *const Window) bool {
        return w.open != 0;
    }

    pub fn setOpen(w: *Window, on: bool) void {
        w.open = cb(on);
    }
};

pub const ListRange = struct { first: usize, last: usize };

fn items(list: []const [*:0]const u8) [*c]const [*c]const u8 {
    return @ptrCast(list.ptr);
}

pub const Ui = opaque {
    pub fn raw(u: *Ui) *c.goome_ui {
        return @ptrCast(u);
    }

    pub fn deinit(u: *Ui) void {
        c.goome_ui_free(u.raw());
    }

    pub fn theme(u: *Ui) *Theme {
        return c.goome_ui_theme(u.raw());
    }

    pub fn themeDark(u: *Ui) void {
        c.goome_ui_theme_dark(u.theme());
    }

    pub fn themeLight(u: *Ui) void {
        c.goome_ui_theme_light(u.theme());
    }

    pub fn themeMake(u: *Ui, accent: u32, dark: bool, r: f64) void {
        c.goome_ui_theme_make(u.theme(), accent, cb(dark), r);
    }

    pub fn themePreset(u: *Ui, preset: c_int) Error!void {
        try check(c.goome_ui_theme_preset(u.theme(), preset));
    }

    pub fn scale(u: *Ui, s: f64) void {
        c.goome_ui_scale(u.raw(), s);
    }

    pub fn config(u: *Ui) *UiConfig {
        return c.goome_ui_cfg(u.raw());
    }

    pub fn bind(u: *Ui, act: c_int, combos: [*:0]const u8) Error!void {
        try check(c.goome_ui_bind(u.raw(), act, combos));
    }

    pub fn feed(u: *Ui, ev: Event) bool {
        return c.goome_ui_feed(u.raw(), ev.raw()) > 0;
    }

    pub fn begin(u: *Ui, mon: i32) ?*Canvas {
        const cv = c.goome_ui_begin(u.raw(), mon);
        if (cv == null) return null;
        return @ptrCast(cv);
    }

    pub fn end(u: *Ui) void {
        c.goome_ui_end(u.raw());
    }

    pub fn hit(u: *Ui, x: f64, y: f64, w: f64, h: f64) void {
        c.goome_ui_hit(u.raw(), x, y, w, h);
    }

    pub fn animating(u: *Ui) bool {
        return c.goome_ui_animating(u.raw()) != 0;
    }

    pub fn wants(u: *Ui) c_int {
        return c.goome_ui_wants(u.raw());
    }

    pub fn wantsMouse(u: *Ui) bool {
        return u.wants() & c.GOOME_WANT_MOUSE != 0;
    }

    pub fn wantsKeyboard(u: *Ui) bool {
        return u.wants() & c.GOOME_WANT_KEYBOARD != 0;
    }

    pub fn autoGrab(u: *Ui, w: c_int) void {
        c.goome_ui_auto_grab(u.raw(), w);
    }

    pub fn window(u: *Ui, title: [*:0]const u8, w: *Window, flags: c_int) bool {
        return c.goome_ui_window(u.raw(), title, &w.x, &w.y, &w.w, &w.h, flags, &w.open) != 0;
    }

    pub fn windowEnd(u: *Ui) void {
        c.goome_ui_window_end(u.raw());
    }

    pub fn row(u: *Ui, cols: i32) void {
        c.goome_ui_row(u.raw(), cols);
    }

    pub fn sameLine(u: *Ui) void {
        c.goome_ui_same_line(u.raw());
    }

    pub fn space(u: *Ui, px: f64) void {
        c.goome_ui_space(u.raw(), px);
    }

    pub fn separator(u: *Ui) void {
        c.goome_ui_separator(u.raw());
    }

    pub fn width(u: *Ui, w: f64) void {
        c.goome_ui_width(u.raw(), w);
    }

    pub fn label(u: *Ui, s: [*:0]const u8) void {
        c.goome_ui_label(u.raw(), "%s", s);
    }

    pub fn labelFmt(u: *Ui, comptime fmt: []const u8, args: anytype) void {
        var buf: [512]u8 = undefined;
        const s = std.fmt.bufPrintZ(&buf, fmt, args) catch blk: {
            buf[buf.len - 1] = 0;
            break :blk buf[0 .. buf.len - 1 :0];
        };
        u.label(s.ptr);
    }

    pub fn heading(u: *Ui, s: [*:0]const u8) void {
        c.goome_ui_heading(u.raw(), s);
    }

    pub fn wrapped(u: *Ui, s: [*:0]const u8) void {
        c.goome_ui_wrapped(u.raw(), s);
    }

    pub fn button(u: *Ui, s: [*:0]const u8) bool {
        return c.goome_ui_button(u.raw(), s) != 0;
    }

    pub fn imageButton(u: *Ui, id: [*:0]const u8, b: *const Bitmap, w: f64, h: f64) bool {
        return c.goome_ui_image_button(u.raw(), id, &b.raw, w, h) != 0;
    }

    pub fn image(u: *Ui, b: *const Bitmap, w: f64, h: f64, r: f64) void {
        c.goome_ui_image(u.raw(), &b.raw, w, h, r);
    }

    pub fn checkbox(u: *Ui, s: [*:0]const u8, v: *bool) bool {
        var t: c_int = cb(v.*);
        const r = c.goome_ui_checkbox(u.raw(), s, &t);
        v.* = t != 0;
        return r != 0;
    }

    pub fn toggle(u: *Ui, s: [*:0]const u8, v: *bool) bool {
        var t: c_int = cb(v.*);
        const r = c.goome_ui_toggle(u.raw(), s, &t);
        v.* = t != 0;
        return r != 0;
    }

    pub fn radio(u: *Ui, s: [*:0]const u8, v: *i32, value: i32) bool {
        return c.goome_ui_radio(u.raw(), s, @ptrCast(v), value) != 0;
    }

    pub fn slider(u: *Ui, s: [*:0]const u8, v: *f64, min: f64, max: f64, fmt: ?[*:0]const u8) bool {
        return c.goome_ui_slider(u.raw(), s, v, min, max, cstr(fmt)) != 0;
    }

    pub fn sliderInt(u: *Ui, s: [*:0]const u8, v: *i32, min: i32, max: i32) bool {
        return c.goome_ui_slider_int(u.raw(), s, @ptrCast(v), min, max) != 0;
    }

    pub fn input(u: *Ui, s: [*:0]const u8, buf: []u8) bool {
        if (buf.len == 0) return false;
        return c.goome_ui_input(u.raw(), s, buf.ptr, @intCast(buf.len)) != 0;
    }

    pub fn inputEx(u: *Ui, s: [*:0]const u8, buf: []u8, flags: c_int, hint: ?[*:0]const u8) bool {
        if (buf.len == 0) return false;
        return c.goome_ui_input_ex(u.raw(), s, buf.ptr, @intCast(buf.len), flags, cstr(hint)) != 0;
    }

    pub fn combo(u: *Ui, s: [*:0]const u8, sel: *i32, list: []const [*:0]const u8) bool {
        return c.goome_ui_combo(u.raw(), s, @ptrCast(sel), items(list), @intCast(list.len)) != 0;
    }

    pub fn selectable(u: *Ui, s: [*:0]const u8, selected: bool) bool {
        return c.goome_ui_selectable(u.raw(), s, cb(selected)) != 0;
    }

    pub fn tabs(u: *Ui, id: [*:0]const u8, names: []const [*:0]const u8, sel: *i32) bool {
        return c.goome_ui_tabs(u.raw(), id, items(names), @intCast(names.len), @ptrCast(sel)) != 0;
    }

    pub fn collapsing(u: *Ui, s: [*:0]const u8, open: ?*bool) bool {
        if (open) |o| {
            var t: c_int = cb(o.*);
            const r = c.goome_ui_collapsing(u.raw(), s, &t);
            o.* = t != 0;
            return r != 0;
        }
        return c.goome_ui_collapsing(u.raw(), s, null) != 0;
    }

    pub fn progress(u: *Ui, frac: f64, s: ?[*:0]const u8) void {
        c.goome_ui_progress(u.raw(), frac, cstr(s));
    }

    pub fn color(u: *Ui, s: [*:0]const u8, argb: *u32) bool {
        return c.goome_ui_color(u.raw(), s, argb) != 0;
    }

    pub fn tooltip(u: *Ui, s: [*:0]const u8) void {
        c.goome_ui_tooltip(u.raw(), s);
    }

    pub fn hovered(u: *Ui) bool {
        return c.goome_ui_hovered(u.raw()) != 0;
    }

    pub fn scrollBegin(u: *Ui, id: [*:0]const u8, h: f64) bool {
        return c.goome_ui_scroll_begin(u.raw(), id, h) != 0;
    }

    pub fn scrollEnd(u: *Ui) void {
        c.goome_ui_scroll_end(u.raw());
    }

    pub fn pushId(u: *Ui, id: [*:0]const u8) void {
        c.goome_ui_push_id(u.raw(), id);
    }

    pub fn pushIndex(u: *Ui, i: usize) void {
        var buf: [24]u8 = undefined;
        const s = std.fmt.bufPrintZ(&buf, "{d}", .{i}) catch unreachable;
        u.pushId(s.ptr);
    }

    pub fn popId(u: *Ui) void {
        c.goome_ui_pop_id(u.raw());
    }

    pub fn app(u: *Ui, title: ?[*:0]const u8, flags: c_int) bool {
        return c.goome_ui_app(u.raw(), cstr(title), flags) != 0;
    }

    pub fn appEnd(u: *Ui) void {
        c.goome_ui_app_end(u.raw());
    }

    pub fn menubarBegin(u: *Ui) bool {
        return c.goome_ui_menubar_begin(u.raw()) != 0;
    }

    pub fn menubarEnd(u: *Ui) void {
        c.goome_ui_menubar_end(u.raw());
    }

    pub fn menuBegin(u: *Ui, s: [*:0]const u8) bool {
        return c.goome_ui_menu_begin(u.raw(), s) != 0;
    }

    pub fn menuEnd(u: *Ui) void {
        c.goome_ui_menu_end(u.raw());
    }

    pub fn menuItem(u: *Ui, s: [*:0]const u8, shortcut: ?[*:0]const u8, checked: ?*bool) bool {
        if (checked) |ch| {
            var t: c_int = cb(ch.*);
            const r = c.goome_ui_menu_item(u.raw(), s, cstr(shortcut), &t);
            ch.* = t != 0;
            return r != 0;
        }
        return c.goome_ui_menu_item(u.raw(), s, cstr(shortcut), null) != 0;
    }

    pub fn menuSeparator(u: *Ui) void {
        c.goome_ui_menu_separator(u.raw());
    }

    pub fn contextBegin(u: *Ui, id: [*:0]const u8) bool {
        return c.goome_ui_context_begin(u.raw(), id) != 0;
    }

    pub fn contextEnd(u: *Ui) void {
        c.goome_ui_context_end(u.raw());
    }

    pub fn popupOpen(u: *Ui, id: [*:0]const u8) void {
        c.goome_ui_popup_open(u.raw(), id);
    }

    pub fn popupBegin(u: *Ui, id: [*:0]const u8) bool {
        return c.goome_ui_popup_begin(u.raw(), id) != 0;
    }

    pub fn popupEnd(u: *Ui) void {
        c.goome_ui_popup_end(u.raw());
    }

    pub fn popupClose(u: *Ui) void {
        c.goome_ui_popup_close(u.raw());
    }

    pub fn modalBegin(u: *Ui, title: [*:0]const u8, open: ?*c_int) bool {
        return c.goome_ui_modal_begin(u.raw(), title, open) != 0;
    }

    pub fn modalEnd(u: *Ui) void {
        c.goome_ui_modal_end(u.raw());
    }

    pub fn toast(u: *Ui, s: [*:0]const u8, ms: i32) void {
        c.goome_ui_toast(u.raw(), s, ms);
    }

    pub fn statusbar(u: *Ui, s: [*:0]const u8) void {
        c.goome_ui_statusbar(u.raw(), s);
    }

    pub fn focused(u: *Ui) bool {
        return c.goome_ui_focused(u.raw()) != 0;
    }

    pub fn setFocus(u: *Ui) void {
        c.goome_ui_set_focus(u.raw());
    }

    pub fn textEdit(u: *Ui, id: [*:0]const u8, buf: []u8, h: f64, flags: c_int) bool {
        if (buf.len == 0) return false;
        return c.goome_ui_text_edit(u.raw(), id, buf.ptr, @intCast(buf.len), h, flags) != 0;
    }

    pub fn tableBegin(u: *Ui, id: [*:0]const u8, cols: i32, h: f64, flags: c_int) bool {
        return c.goome_ui_table_begin(u.raw(), id, cols, h, flags) != 0;
    }

    pub fn tableColumn(u: *Ui, name: [*:0]const u8, w: f64) void {
        c.goome_ui_table_column(u.raw(), name, w);
    }

    pub fn tableSort(u: *Ui, col: *i32, desc: *bool) bool {
        var d: c_int = cb(desc.*);
        const r = c.goome_ui_table_sort(u.raw(), @ptrCast(col), &d);
        desc.* = d != 0;
        return r != 0;
    }

    pub fn tableRow(u: *Ui) void {
        c.goome_ui_table_row(u.raw());
    }

    pub fn tableNext(u: *Ui) void {
        c.goome_ui_table_next(u.raw());
    }

    pub fn tableEnd(u: *Ui) void {
        c.goome_ui_table_end(u.raw());
    }

    pub fn tree(u: *Ui, s: [*:0]const u8, open: ?*bool) bool {
        if (open) |o| {
            var t: c_int = cb(o.*);
            const r = c.goome_ui_tree(u.raw(), s, &t);
            o.* = t != 0;
            return r != 0;
        }
        return c.goome_ui_tree(u.raw(), s, null) != 0;
    }

    pub fn treeEnd(u: *Ui) void {
        c.goome_ui_tree_end(u.raw());
    }

    pub fn listClip(u: *Ui, count: usize, row_h: f64) ListRange {
        var first: c_int = 0;
        var last: c_int = 0;
        _ = c.goome_ui_list_clip(u.raw(), @intCast(count), row_h, &first, &last);
        const f: usize = @intCast(@max(0, first));
        const l: usize = @intCast(@max(first, last));
        return .{ .first = f, .last = l };
    }

    pub fn dragFloat(u: *Ui, s: [*:0]const u8, v: *f64, speed: f64, min: f64, max: f64, fmt: ?[*:0]const u8) bool {
        return c.goome_ui_drag_float(u.raw(), s, v, speed, min, max, cstr(fmt)) != 0;
    }

    pub fn dragInt(u: *Ui, s: [*:0]const u8, v: *i32, speed: f64, min: i32, max: i32) bool {
        return c.goome_ui_drag_int(u.raw(), s, @ptrCast(v), speed, min, max) != 0;
    }

    pub fn number(u: *Ui, s: [*:0]const u8, v: *f64, step: f64, fmt: ?[*:0]const u8) bool {
        return c.goome_ui_number(u.raw(), s, v, step, cstr(fmt)) != 0;
    }

    pub fn plotLines(u: *Ui, s: [*:0]const u8, v: []const f32, min: f64, max: f64, h: f64) void {
        c.goome_ui_plot_lines(u.raw(), s, v.ptr, @intCast(v.len), min, max, h);
    }

    pub fn plotBars(u: *Ui, s: [*:0]const u8, v: []const f32, min: f64, max: f64, h: f64) void {
        c.goome_ui_plot_bars(u.raw(), s, v.ptr, @intCast(v.len), min, max, h);
    }

    pub fn splitBegin(u: *Ui, id: [*:0]const u8, vertical: bool, frac: *f64) bool {
        return c.goome_ui_split_begin(u.raw(), id, cb(vertical), frac) != 0;
    }

    pub fn splitNext(u: *Ui) void {
        c.goome_ui_split_next(u.raw());
    }

    pub fn splitEnd(u: *Ui) void {
        c.goome_ui_split_end(u.raw());
    }

    pub fn dragSource(u: *Ui, kind: [*:0]const u8, data: []const u8) bool {
        return c.goome_ui_drag_source(u.raw(), kind, data.ptr, @intCast(data.len)) != 0;
    }

    pub fn dropTarget(u: *Ui, kind: [*:0]const u8, buf: []u8) ?[]u8 {
        const n = c.goome_ui_drop_target(u.raw(), kind, buf.ptr, @intCast(buf.len));
        if (n <= 0) return null;
        return buf[0..@min(buf.len, @as(usize, @intCast(n)))];
    }

    pub fn spinner(u: *Ui, sz: f64) void {
        c.goome_ui_spinner(u.raw(), sz);
    }

    pub fn link(u: *Ui, s: [*:0]const u8) bool {
        return c.goome_ui_link(u.raw(), s) != 0;
    }

    pub fn badge(u: *Ui, s: [*:0]const u8, argb: u32) void {
        c.goome_ui_badge(u.raw(), s, argb);
    }

    pub fn pos(u: *Ui, x: f64, y: f64) void {
        c.goome_ui_pos(u.raw(), x, y);
    }

    pub fn size(u: *Ui, w: f64, h: f64) void {
        c.goome_ui_size(u.raw(), w, h);
    }

    pub fn pushColor(u: *Ui, what: c_int, argb: u32) void {
        c.goome_ui_push_color(u.raw(), what, argb);
    }

    pub fn pushNum(u: *Ui, what: c_int, v: f64) void {
        c.goome_ui_push_num(u.raw(), what, v);
    }

    pub fn pushRadii(u: *Ui, r: Radii) void {
        c.goome_ui_push_radii(u.raw(), r);
    }

    pub fn pushFont(u: *Ui, f: ?*Font) void {
        c.goome_ui_push_font(u.raw(), Font.ptr(f));
    }

    pub fn pushSkin(u: *Ui, kind: c_int, s: ?*const Skin) void {
        c.goome_ui_push_skin(u.raw(), kind, s);
    }

    pub fn pushTheme(u: *Ui, t: *const Theme) void {
        c.goome_ui_push_theme(u.raw(), t);
    }

    pub fn pushIcon(u: *Ui, icon: c_int, b: ?*const Bitmap) void {
        c.goome_ui_push_icon(u.raw(), icon, if (b) |bm| &bm.raw else null);
    }

    pub fn pop(u: *Ui, n: i32) void {
        c.goome_ui_pop(u.raw(), n);
    }

    pub fn custom(u: *Ui, id: [*:0]const u8, w: f64, h: f64, flags: c_int, it: *Item) bool {
        return c.goome_ui_custom(u.raw(), id, w, h, flags, it) != 0;
    }

    pub fn canvas(u: *Ui) ?*Canvas {
        const cv = c.goome_ui_canvas(u.raw());
        if (cv == null) return null;
        return @ptrCast(cv);
    }

    pub fn anim(u: *Ui, id: [*:0]const u8, target: f64, ms: f64, e: Ease) f64 {
        return c.goome_ui_anim(u.raw(), id, target, ms, @intFromEnum(e));
    }

    pub fn animColor(u: *Ui, id: [*:0]const u8, target: u32, ms: f64, e: Ease) u32 {
        return c.goome_ui_anim_color(u.raw(), id, target, ms, @intFromEnum(e));
    }

    pub fn a11yOn(u: *Ui, on: bool) void {
        c.goome_ui_a11y(u.raw(), cb(on));
    }

    pub fn a11yRole(u: *Ui, role: Role, name: ?[*:0]const u8) void {
        c.goome_ui_a11y_role(u.raw(), @intFromEnum(role), cstr(name));
    }

    pub fn a11yValue(u: *Ui, value: ?[*:0]const u8) void {
        c.goome_ui_a11y_value(u.raw(), cstr(value));
    }

    pub fn a11yRaw(u: *Ui, buf: []RawA11yNode) usize {
        const n = c.goome_a11y_tree(u.raw(), buf.ptr, @intCast(buf.len));
        return @intCast(@max(0, n));
    }

    pub fn a11yTree(u: *Ui, allocator: std.mem.Allocator) !A11yTree {
        const buf = try allocator.alloc(RawA11yNode, u.a11yRaw(&.{}));
        errdefer allocator.free(buf);
        _ = u.a11yRaw(buf);
        const nodes = try allocator.alloc(A11yNode, buf.len);
        errdefer allocator.free(nodes);
        for (buf, nodes) |*r, *n| {
            n.* = .{
                .role = @enumFromInt(r.role),
                .parent = if (r.parent >= 0 and r.parent < buf.len) @intCast(r.parent) else null,
                .states = r.states,
                .x = r.x,
                .y = r.y,
                .w = r.w,
                .h = r.h,
                .label = std.mem.sliceTo(&r.label, 0),
                .value = std.mem.sliceTo(&r.value, 0),
                .id = r.id,
                .num = r.num,
                .min = r.min,
                .max = r.max,
                .caret = r.caret,
            };
        }
        return .{ .raw = buf, .nodes = nodes, .allocator = allocator };
    }

    pub fn store(u: *Ui, id: [*:0]const u8, n: usize) ?[]f64 {
        const p = c.goome_ui_store(u.raw(), id, @intCast(n));
        if (p == null) return null;
        return p[0..n];
    }
};

pub fn text(buf: []const u8) []const u8 {
    return std.mem.sliceTo(buf, 0);
}

pub fn setText(buf: []u8, s: []const u8) void {
    if (buf.len == 0) return;
    const n = @min(s.len, buf.len - 1);
    @memcpy(buf[0..n], s[0..n]);
    buf[n] = 0;
}
