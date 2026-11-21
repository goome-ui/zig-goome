//! Zig bindings for goome, the overlay and ui library. `Goome` is the window or overlay, `Canvas` is what you draw on, and `Ui` is the widget kit.
//! Colors are plain 0xAARRGGBB and coords are logical unless a note says real px.

const std = @import("std");

/// The raw C header, for anything the wrapper doesnt cover.
pub const c = @cImport({
    @cInclude("goome.h");
});

/// goome version string.
pub const version: []const u8 = c.GOOME_VERSION;

/// What goome calls can fail with. Maps the C GOOME_E* codes.
pub const Error = error{
    /// This backend or os cant do that.
    NotSupported,
    /// The os or user said no (screen access, permissions).
    Denied,
    /// No display to open on.
    NoDisplay,
    /// The thing you were using went away, like an unplugged monitor.
    Gone,
    /// Not ready yet, try again.
    Again,
    OutOfMemory,
    /// A bad argument, like an empty buffer or a too small slice.
    BadArgument,
    /// A font or bitmap failed to load.
    LoadFailed,
    /// Some other error code.
    Unknown,
};

/// Turns a negative C error code into an `Error`.
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

/// Turns an `Error` back into its C code.
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

/// Text for a C error code.
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

/// Integer rectangle, x y w h.
pub const Rect = c.goome_rect;
/// One monitor: id, name, area in logical desktop coords, scale, real px size and rotation.
pub const Monitor = c.goome_monitor;
/// Corner radii, one per corner (tl, tr, br, bl).
pub const Radii = c.goome_radii;
/// All the colors, sizes, fonts and skins the ui uses. Get it with `Ui.theme`.
pub const Theme = c.goome_theme;
/// A nine-slice bitmap skin: the bitmap plus its l t r b border sizes in bitmap px.
pub const Skin = c.goome_skin;
/// What `Ui.custom` fills in: where the item ended up, pointer state, drag deltas and the key pressed this frame.
pub const Item = c.goome_ui_item;
/// Ui behavior settings (tooltip delay, double click timing, key binds, cursors and so on). Get it with `Ui.config`.
pub const UiConfig = c.goome_ui_config;
/// A key plus its modifier bits, as stored in `UiConfig`.
pub const KeyCombo = c.goome_combo;

/// Makes a `Rect`.
pub fn rect(x: c_int, y: c_int, w: c_int, h: c_int) Rect {
    return .{ .x = x, .y = y, .w = w, .h = h };
}

/// Same radius on all four corners.
pub fn radius(r: f64) Radii {
    return c.goome_radius(r);
}

/// A different radius per corner, clockwise from the top left.
pub fn corners(tl: f64, tr: f64, br: f64, bl: f64) Radii {
    return .{ .tl = tl, .tr = tr, .br = br, .bl = bl };
}

/// Which backend to use. `auto` picks one, or force one. The GOOME_BACKEND env var wins over this.
pub const Backend = enum(c_int) {
    auto = c.GOOME_AUTO,
    wayland = c.GOOME_WAYLAND,
    gnome = c.GOOME_GNOME,
    portal = c.GOOME_PORTAL,
    x11 = c.GOOME_X11,
    win32 = c.GOOME_WIN32,
    macos = c.GOOME_MACOS,
    /// Scripted backend for tests.
    @"test" = c.GOOME_TEST,
    /// No window, you pull the frames yourself.
    offscreen = c.GOOME_OFFSCREEN,
};

/// How goome shows itself.
pub const Mode = enum(c_int) {
    /// Transparent overlay on top of the desktop.
    overlay = c.GOOME_MODE_OVERLAY,
    /// A normal window.
    window = c.GOOME_MODE_WINDOW,
    /// No window, renders to memory only.
    offscreen = c.GOOME_MODE_OFFSCREEN,
    _,
};

/// Kinds of events `Goome.poll` can give you.
pub const EventType = enum(c_int) {
    none = c.GOOME_NONE,
    down = c.GOOME_DOWN,
    up = c.GOOME_UP,
    motion = c.GOOME_MOTION,
    scroll = c.GOOME_SCROLL,
    /// A key press. Only comes while the keyboard is on.
    key = c.GOOME_KEY,
    /// A combo you registered with `Goome.hotkey`, `id` says which.
    hotkey = c.GOOME_HOTKEY,
    /// A line came in on the control fifo, see `Event.message`.
    control = c.GOOME_CONTROL,
    /// The monitor list changed, ask `Goome.monitors` again.
    monitors = c.GOOME_MONITORS,
    quit = c.GOOME_QUIT,
    /// The window close button, alt-f4 or cmd-w. The app decides what to do.
    close = c.GOOME_CLOSE,
    /// Window focus changed, `id` is 1 when gained and 0 when lost.
    focus = c.GOOME_FOCUS,
    /// A file got dropped on the window. `Goome.dropPath` has the full path.
    drop = c.GOOME_DROP,
    /// An ime, dead key or compose finished some text. `Goome.eventText` has all of it.
    text = c.GOOME_TEXT,
    /// The text being composed changed. Empty means composing ended.
    preedit = c.GOOME_PREEDIT,
    _,
};

/// One input event. Which fields matter depends on `kind`.
pub const Event = extern struct {
    /// What kind of event it is.
    kind: EventType = .none,
    /// Pointer x, logical.
    x: f64 = 0,
    /// Pointer y, logical.
    y: f64 = 0,
    /// Monitor the event happened on.
    mon: c_int = 0,
    /// Mouse button, 1 left, 2 middle, 3 right.
    button: c_int = 0,
    /// Scroll notches, +1 is down.
    dy: c_int = 0,
    /// Lowercase ascii or one of the `key` constants.
    key: c_int = 0,
    /// Modifier bits from `mod`.
    mods: c_int = 0,
    /// UTF-8 the key typed, can be empty. Use `typed`.
    text: [8]u8 = [_]u8{0} ** 8,
    /// Hotkey id, or for focus 1 = gained, 0 = lost, or the caret byte offset for preedit.
    id: c_int = 0,
    /// Control line, dropped path or text, cut at 63 bytes. Use `message`.
    msg: [64]u8 = [_]u8{0} ** 64,

    /// The text the key typed, as a slice.
    pub fn typed(e: *const Event) []const u8 {
        return std.mem.sliceTo(&e.text, 0);
    }

    /// The `msg` field as a slice.
    pub fn message(e: *const Event) []const u8 {
        return std.mem.sliceTo(&e.msg, 0);
    }

    /// The same event as the C struct.
    pub fn raw(e: *const Event) *const c.goome_event {
        return @ptrCast(e);
    }
};

/// Key codes for `Event.key`. Letters are just lowercase ascii.
pub const key = struct {
    /// Backspace
    pub const backspace = c.GOOME_K_BACKSPACE;
    /// Tab
    pub const tab = c.GOOME_K_TAB;
    /// Enter
    pub const enter = c.GOOME_K_ENTER;
    /// Escape
    pub const esc = c.GOOME_K_ESC;
    /// Space
    pub const space = c.GOOME_K_SPACE;
    /// Delete
    pub const delete = c.GOOME_K_DELETE;
    /// F1, F2 to F11 follow in order up to `f12`.
    pub const f1 = c.GOOME_K_F1;
    /// F12
    pub const f12 = c.GOOME_K_F12;
    /// Left arrow
    pub const left = c.GOOME_K_LEFT;
    /// Right arrow
    pub const right = c.GOOME_K_RIGHT;
    /// Up arrow
    pub const up = c.GOOME_K_UP;
    /// Down arrow
    pub const down = c.GOOME_K_DOWN;
    /// Home
    pub const home = c.GOOME_K_HOME;
    /// End
    pub const end = c.GOOME_K_END;
    /// Page up
    pub const pgup = c.GOOME_K_PGUP;
    /// Page down
    pub const pgdn = c.GOOME_K_PGDN;
    /// Insert
    pub const insert = c.GOOME_K_INSERT;
};

/// Modifier bits for `Event.mods` and combos.
pub const mod = struct {
    /// Shift held.
    pub const shift = c.GOOME_SHIFT;
    /// Ctrl held.
    pub const ctrl = c.GOOME_CTRL;
    /// Alt held.
    pub const alt = c.GOOME_ALT;
    /// Super held (the windows or cmd key).
    pub const super = c.GOOME_SUPER;
};

/// Capability bits `Goome.caps` can return. Not every backend has all of them.
pub const cap = struct {
    /// Can grab the screen.
    pub const capture = c.GOOME_CAP_CAPTURE;
    /// Can read the pointer anywhere, not just over our window.
    pub const global_pointer = c.GOOME_CAP_GLOBAL_POINTER;
    /// Can register global hotkeys.
    pub const hotkeys = c.GOOME_CAP_HOTKEYS;
    /// Can keep our overlay out of grabs.
    pub const hide_self = c.GOOME_CAP_HIDE_SELF;
    /// Can take keyboard input.
    pub const keyboard = c.GOOME_CAP_KEYBOARD;
    /// Can move, resize and change the window.
    pub const window = c.GOOME_CAP_WINDOW;
    /// Can read and write the clipboard.
    pub const clipboard = c.GOOME_CAP_CLIPBOARD;
    /// Can change the cursor shape.
    pub const cursor = c.GOOME_CAP_CURSOR;
    /// Can grab focus and the pointer.
    pub const grab = c.GOOME_CAP_GRAB;
};

/// Flags for `Options.window_flags`.
pub const window_flags = struct {
    /// The user can resize it.
    pub const resizable = c.GOOME_WINDOW_RESIZABLE;
    /// No window border.
    pub const borderless = c.GOOME_WINDOW_BORDERLESS;
    /// Transparent background.
    pub const transparent = c.GOOME_WINDOW_TRANSPARENT;
    /// Stays above other windows.
    pub const on_top = c.GOOME_WINDOW_ON_TOP;
    /// Starts hidden, show it with `Goome.show`.
    pub const hidden = c.GOOME_WINDOW_HIDDEN;
    /// Opens centered.
    pub const center = c.GOOME_WINDOW_CENTER;
    /// No titlebar.
    pub const no_titlebar = c.GOOME_WINDOW_NO_TITLEBAR;
    /// Windows only, no console window.
    pub const no_console = c.GOOME_WINDOW_NO_CONSOLE;
};

/// Flags for `Ui.window`.
pub const win = struct {
    /// Can be dragged around.
    pub const move = c.GOOME_WIN_MOVE;
    /// Can be resized.
    pub const resize = c.GOOME_WIN_RESIZE;
    /// Has a collapse button.
    pub const collapse = c.GOOME_WIN_COLLAPSE;
    /// No titlebar.
    pub const no_title = c.GOOME_WIN_NO_TITLE;
    /// Has a close button.
    pub const close = c.GOOME_WIN_CLOSE;
};

/// Bits from `Ui.wants`, what the ui wants from the os right now.
pub const want = struct {
    /// The ui wants the mouse.
    pub const mouse = c.GOOME_WANT_MOUSE;
    /// The ui wants the keyboard.
    pub const keyboard = c.GOOME_WANT_KEYBOARD;
};

/// Easing curves for animations.
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

/// Runs the curve `e` at `t`, with t from 0 to 1.
pub fn ease(e: Ease, t: f64) f64 {
    return c.goome_ease(@intFromEnum(e), t);
}

/// Paragraph direction for text.
pub const TextDir = enum(c_int) {
    /// Picked from the first strong letter of each line.
    auto = c.GOOME_DIR_AUTO,
    ltr = c.GOOME_DIR_LTR,
    rtl = c.GOOME_DIR_RTL,
};

/// Sets the paragraph direction for all text.
pub fn textDir(dir: TextDir) void {
    c.goome_text_dir(@intFromEnum(dir));
}

/// Accessibility roles for widgets.
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

/// Accessibility state bits for `A11yNode.states`.
pub const a11y = struct {
    /// Has keyboard focus.
    pub const focused = c.GOOME_A11Y_FOCUSED;
    /// Checked or on.
    pub const checked = c.GOOME_A11Y_CHECKED;
    /// Disabled.
    pub const disabled = c.GOOME_A11Y_DISABLED;
    /// Open or expanded.
    pub const expanded = c.GOOME_A11Y_EXPANDED;
    /// Selected.
    pub const selected = c.GOOME_A11Y_SELECTED;
};

/// The C accessibility node.
pub const RawA11yNode = c.goome_a11y_node;

/// One node of the accessibility tree.
pub const A11yNode = struct {
    role: Role,
    /// Index of the parent node, null for the root.
    parent: ?usize,
    /// Bits from `a11y`.
    states: c_int,
    /// Position and size, logical.
    x: f64,
    y: f64,
    w: f64,
    h: f64,
    label: []const u8,
    value: []const u8,
    id: u32,
    /// Current value for sliders and the like, with `min` and `max` as the range.
    num: f64,
    min: f64,
    max: f64,
    /// Caret byte offset in `value` for inputs.
    caret: i32,

    /// True if the state bit is set.
    pub fn has(n: A11yNode, st: c_int) bool {
        return n.states & st != 0;
    }
};

/// The accessibility tree from `Ui.a11yTree`. Free it with `deinit`.
pub const A11yTree = struct {
    /// The C nodes `nodes` was built from.
    raw: []RawA11yNode,
    /// The nodes, parents are indexes into this slice.
    nodes: []A11yNode,
    allocator: std.mem.Allocator,

    /// Frees the tree.
    pub fn deinit(t: *A11yTree) void {
        t.allocator.free(t.nodes);
        t.allocator.free(t.raw);
        t.raw = &.{};
        t.nodes = &.{};
    }

    /// Index of the first node with this role and label, or null.
    pub fn find(t: A11yTree, role: Role, label: []const u8) ?usize {
        for (t.nodes, 0..) |n, i| {
            if (n.role == role and std.mem.eql(u8, n.label, label)) return i;
        }
        return null;
    }
};

/// Byte order in memory for `Goome.frameCopy`. The non premul ones unpremultiply for you.
pub const Format = enum(c_int) {
    bgra_premul = c.GOOME_FMT_BGRA_PREMUL,
    rgba_premul = c.GOOME_FMT_RGBA_PREMUL,
    bgra = c.GOOME_FMT_BGRA,
    rgba = c.GOOME_FMT_RGBA,
};

/// Settings for `Goome.open`. Zero or null means default.
pub const Options = struct {
    /// Window title, null means "goome".
    title: ?[*:0]const u8 = null,
    backend: Backend = .auto,
    /// Where the portal token and control fifo live, null means neither.
    state_dir: ?[*:0]const u8 = null,
    /// Overlay only, never asks for screen access.
    no_capture: bool = false,
    /// Capture rate for gnome and portal streams, 0 means 5.
    capture_fps: i32 = 0,
    /// Keep our overlay out of screen grabs where the os lets us.
    hide_self: bool = false,
    /// Test backend only, same as the GOOME_TEST_FRAMES env var.
    test_frames: ?[*:0]const u8 = null,
    /// Test backend only, same as the GOOME_TEST_SCRIPT env var.
    test_script: ?[*:0]const u8 = null,
    /// Test backend only, same as the GOOME_TEST_SHOTS env var.
    test_shots: ?[*:0]const u8 = null,
    mode: Mode = .overlay,
    /// Window or offscreen width, logical. 0 means 960.
    width: i32 = 0,
    /// Window or offscreen height, logical. 0 means 640.
    height: i32 = 0,
    /// Smallest window width, window mode only. 0 means none.
    min_width: i32 = 0,
    /// Smallest window height, window mode only. 0 means none.
    min_height: i32 = 0,
    /// Bits from `window_flags`.
    window_flags: c_int = 0,
    /// Offscreen only, real px per logical px. 0 means 1.
    scale: f64 = 0,

    /// Converts to the C options struct.
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

/// A parsed key combo.
pub const Combo = struct { key: c_int, mods: c_int };

/// Parses a combo string into a key and modifier bits.
pub fn parseCombo(combo: [*:0]const u8) Error!Combo {
    var k: c_int = 0;
    var m: c_int = 0;
    try check(c.goome_parse_combo(combo, &k, &m));
    return .{ .key = k, .mods = m };
}

/// Sends a line to the control fifo of a running goome that uses this `state_dir`.
pub fn send(state_dir: [*:0]const u8, msg: [*:0]const u8) Error!void {
    try check(c.goome_send(state_dir, msg));
}

/// Milliseconds on goome's clock, good for timing frames.
pub fn nowMs() i64 {
    return @intCast(c.goome_now_ms());
}

/// Writes pixels to a .ppm file. `stride` is in pixels.
pub fn savePpm(path: [*:0]const u8, px: []const u32, w: usize, h: usize, stride: usize) Error!void {
    if (h > 0 and px.len < (h - 1) * stride + w) return error.BadArgument;
    try check(c.goome_save_ppm(path, px.ptr, @intCast(w), @intCast(h), @intCast(stride)));
}

/// Frame pacing state, start it with the default value.
pub const Pacer = struct {
    raw: c.goome_pacer = .{},

    /// How many ms to wait before the next frame at `fps`, 0 means its time. Doesnt sleep by itself.
    pub fn wait(p: *Pacer, fps: i32) i32 {
        return c.goome_pace(&p.raw, fps);
    }
};

/// A grabbed or rendered image. Pixels are owned by goome and good until the next grab or `Goome.begin`.
pub const Image = struct {
    raw: c.goome_image,

    /// Width in real px.
    pub fn width(img: Image) usize {
        return @intCast(img.raw.w);
    }

    /// Height in real px.
    pub fn height(img: Image) usize {
        return @intCast(img.raw.h);
    }

    /// Row length in pixels, can be wider than `width`.
    pub fn stride(img: Image) usize {
        return @intCast(img.raw.stride);
    }

    /// All the pixels, `stride` times `height` of them.
    pub fn pixels(img: Image) []u32 {
        if (img.raw.px == null) return &.{};
        return img.raw.px[0 .. img.height() * img.stride()];
    }

    /// One row of pixels, `width` long.
    pub fn row(img: Image, y: usize) []u32 {
        return img.pixels()[y * img.stride() ..][0..img.width()];
    }

    /// One pixel.
    pub fn pixel(img: Image, x: usize, y: usize) u32 {
        return img.pixels()[y * img.stride() + x];
    }

    /// Writes the image to a .ppm file.
    pub fn savePpm(img: Image, path: [*:0]const u8) Error!void {
        try savePpmRaw(path, img.raw.px, img.raw.w, img.raw.h, img.raw.stride);
    }
};

fn savePpmRaw(path: [*:0]const u8, px: [*c]const u32, w: c_int, h: c_int, stride: c_int) Error!void {
    try check(c.goome_save_ppm(path, px, w, h, stride));
}

/// Pointer position (logical) and the mouse button bits held.
pub const Pointer = struct { x: f64, y: f64, buttons: c_int };

/// A goome instance: an overlay, a window, or an offscreen renderer. Make one with `open`, `openApp` or `openOffscreen`.
pub const Goome = opaque {
    fn raw(g: *Goome) *c.goome {
        return @ptrCast(g);
    }

    /// Opens goome with the given options.
    pub fn open(o: Options) Error!*Goome {
        var err: c_int = 0;
        const opts = o.toC();
        const g = c.goome_open(&opts, &err) orelse return toError(if (err < 0) err else c.GOOME_ENODISPLAY);
        return @ptrCast(g);
    }

    /// Opens a normal resizable window, centered.
    pub fn openApp(title: [*:0]const u8, w: i32, h: i32) Error!*Goome {
        var err: c_int = 0;
        const g = c.goome_open_app(title, w, h, &err) orelse return toError(if (err < 0) err else c.GOOME_ENODISPLAY);
        return @ptrCast(g);
    }

    /// Opens an offscreen renderer. Size is logical, `scale` is real px per logical px.
    pub fn openOffscreen(w: i32, h: i32, scale: f64) Error!*Goome {
        return open(.{ .mode = .offscreen, .width = w, .height = h, .scale = scale });
    }

    /// Closes it.
    pub fn deinit(g: *Goome) void {
        c.goome_close(g.raw());
    }

    /// Text for the last error, empty if none.
    pub fn lastError(g: *Goome) [:0]const u8 {
        return span(c.goome_error(g.raw())) orelse "";
    }

    /// Name of the backend that got picked.
    pub fn backendName(g: *Goome) [:0]const u8 {
        return span(c.goome_backend_name(g.raw())) orelse "";
    }

    /// Capability bits, see `cap`.
    pub fn caps(g: *Goome) c_int {
        return c.goome_caps(g.raw());
    }

    /// True if the backend has that `cap` bit.
    pub fn can(g: *Goome, what: c_int) bool {
        return g.caps() & what != 0;
    }

    /// The mode it was opened in.
    pub fn mode(g: *Goome) Mode {
        return @enumFromInt(c.goome_mode(g.raw()));
    }

    /// Fills `buf` with the monitors and gives back the part that got filled.
    pub fn monitors(g: *Goome, buf: []Monitor) []Monitor {
        const n = c.goome_monitors(g.raw(), buf.ptr, @intCast(buf.len));
        if (n <= 0) return buf[0..0];
        return buf[0..@min(buf.len, @as(usize, @intCast(n)))];
    }

    /// Grabs a monitor. `area` is the part to grab (logical), null for all of it.
    pub fn capture(g: *Goome, mon: i32, area: ?Rect) Error!Image {
        var img: c.goome_image = .{};
        const r: [*c]const Rect = if (area) |*a| a else null;
        try check(c.goome_capture(g.raw(), mon, r, &img));
        return .{ .raw = img };
    }

    /// Alpha of our own overlay at x,y, 0 to 255. For masking our overlay out of a grab.
    pub fn alphaAt(g: *Goome, x: f64, y: f64) u8 {
        const a = c.goome_alpha_at(g.raw(), x, y);
        return if (a < 0) 0 else @intCast(a);
    }

    /// Starts a frame on a monitor. Null means nothing to draw on, skip the frame.
    pub fn begin(g: *Goome, mon: i32) ?*Canvas {
        const cv = c.goome_begin(g.raw(), mon);
        if (cv == null) return null;
        return @ptrCast(cv);
    }

    /// Sends the frame. `hits` are the rects that take clicks, everything else is click-through.
    pub fn end(g: *Goome, cv: *Canvas, hits: []const Rect) Error!void {
        try check(c.goome_end(g.raw(), cv.raw(), hits.ptr, @intCast(hits.len)));
    }

    /// Waits up to `timeout_ms` for an event. Null if nothing came.
    pub fn poll(g: *Goome, timeout_ms: i32) Error!?Event {
        var ev: Event = .{};
        const n = c.goome_poll(g.raw(), @ptrCast(&ev), timeout_ms);
        if (n < 0) return toError(n);
        if (n == 0) return null;
        return ev;
    }

    /// Where the pointer is and which buttons are held. Null if it cant be read.
    pub fn pointer(g: *Goome) ?Pointer {
        var p: Pointer = .{ .x = 0, .y = 0, .buttons = 0 };
        if (c.goome_pointer(g.raw(), &p.x, &p.y, &p.buttons) < 0) return null;
        return p;
    }

    /// Turns keyboard input on or off. Its off by default so the overlay doesnt eat what you type in other apps.
    pub fn keyboard(g: *Goome, on: bool) Error!void {
        try check(c.goome_keyboard(g.raw(), cb(on)));
    }

    /// Overlay: takes focus and pointer capture until you call it with false. Window: drags keep going outside it.
    pub fn grab(g: *Goome, on: bool) Error!void {
        try check(c.goome_grab(g.raw(), cb(on)));
    }

    /// True while grabbed.
    pub fn grabbed(g: *Goome) bool {
        return c.goome_grabbed(g.raw()) > 0;
    }

    /// Registers a global hotkey. It comes back as an `EventType.hotkey` event with this `id`.
    pub fn hotkey(g: *Goome, combo: [*:0]const u8, id: i32) Error!void {
        try check(c.goome_hotkey(g.raw(), combo, id));
    }

    /// Path of the control fifo, null if there isnt one.
    pub fn controlPath(g: *Goome) ?[:0]const u8 {
        return span(c.goome_control_path(g.raw()));
    }

    /// Changes the window title.
    pub fn setTitle(g: *Goome, title: [*:0]const u8) Error!void {
        try check(c.goome_window_title(g.raw(), title));
    }

    /// Sets the client size, logical.
    pub fn setSize(g: *Goome, w: i32, h: i32) Error!void {
        try check(c.goome_window_size(g.raw(), w, h));
    }

    /// Window x and y. NotSupported where the os wont say (wayland).
    pub fn position(g: *Goome) Error![2]i32 {
        var x: c_int = 0;
        var y: c_int = 0;
        try check(c.goome_window_pos(g.raw(), &x, &y, 0));
        return .{ x, y };
    }

    /// Moves the window. NotSupported where the os wont allow it (wayland).
    pub fn setPosition(g: *Goome, x: i32, y: i32) Error!void {
        var xx: c_int = x;
        var yy: c_int = y;
        try check(c.goome_window_pos(g.raw(), &xx, &yy, 1));
    }

    /// Sets the window state: normal, minimized, maximized or fullscreen (GOOME_STATE_*).
    pub fn setState(g: *Goome, st: c_int) Error!void {
        try check(c.goome_window_state(g.raw(), st));
    }

    /// Current window state (GOOME_STATE_*).
    pub fn state(g: *Goome) c_int {
        return c.goome_window_get_state(g.raw());
    }

    /// Starts a native window move (0) or resize (GOOME_EDGE_* bits) from the press happening right now.
    pub fn drag(g: *Goome, edges: c_int) Error!void {
        try check(c.goome_window_drag(g.raw(), edges));
    }

    /// Shows or hides the window.
    pub fn show(g: *Goome, on: bool) Error!void {
        try check(c.goome_window_show(g.raw(), cb(on)));
    }

    /// Sets the mouse cursor shape (GOOME_CURSOR_*).
    pub fn setCursor(g: *Goome, shape: c_int) Error!void {
        try check(c.goome_cursor(g.raw(), shape));
    }

    /// Last cursor shape asked for. Offscreen embedders read this.
    pub fn cursor(g: *Goome) c_int {
        return c.goome_cursor_shape(g.raw());
    }

    /// Puts UTF-8 text on the clipboard.
    pub fn setClipboard(g: *Goome, utf8: [*:0]const u8) Error!void {
        try check(c.goome_clipboard_set(g.raw(), utf8));
    }

    /// Copies the clipboard text into `buf` and gives back what fit. Can block for about 250ms on x11 and wayland.
    pub fn clipboard(g: *Goome, buf: []u8) Error![]u8 {
        if (buf.len == 0) return error.BadArgument;
        const n = try checkN(c.goome_clipboard_get(g.raw(), buf.ptr, @intCast(buf.len)));
        return buf[0..@min(n, buf.len - 1)];
    }

    /// Full path of the last drop event, good until the next poll.
    pub fn dropPath(g: *Goome) ?[:0]const u8 {
        return span(c.goome_drop_path(g.raw()));
    }

    /// Full UTF-8 of the last text or preedit event, good until the next poll.
    pub fn eventText(g: *Goome) [:0]const u8 {
        return span(c.goome_event_text(g.raw())) orelse "";
    }

    /// Byte offset of the caret in the last preedit text.
    pub fn preeditCursor(g: *Goome) usize {
        return @intCast(@max(0, c.goome_preedit_cursor(g.raw())));
    }

    /// Turns ime on or off. `caret` (logical) is where the candidate window goes.
    pub fn textInput(g: *Goome, on: bool, caret: ?Rect) Error!void {
        const r: [*c]const Rect = if (caret) |*a| a else null;
        try check(c.goome_text_input(g.raw(), cb(on), r));
    }

    /// Queues an event yourself, works in any mode.
    pub fn push(g: *Goome, ev: Event) Error!void {
        try check(c.goome_push(g.raw(), ev.raw()));
    }

    /// Queues a left click at x,y, down then up.
    pub fn pushClick(g: *Goome, x: f64, y: f64) Error!void {
        try g.push(.{ .kind = .down, .x = x, .y = y, .button = 1 });
        try g.push(.{ .kind = .up, .x = x, .y = y, .button = 1 });
    }

    /// Resizes an offscreen renderer. Offscreen only.
    pub fn resize(g: *Goome, w: i32, h: i32, scale: f64) Error!void {
        try check(c.goome_resize(g.raw(), w, h, scale));
    }

    /// The last frame `end` sent, premultiplied argb. Good until the next `begin`.
    pub fn frame(g: *Goome) Error!Image {
        var img: c.goome_image = .{};
        try check(c.goome_frame(g.raw(), &img));
        return .{ .raw = img };
    }

    /// True if x,y is inside the hit rects of the last `end`.
    pub fn hit(g: *Goome, x: f64, y: f64) bool {
        return c.goome_hit(g.raw(), x, y) > 0;
    }

    /// The real px rect that changed since the last call, null if nothing did. The first one after open or resize is the whole frame.
    pub fn frameDirty(g: *Goome) ?Rect {
        var r: Rect = .{};
        if (c.goome_frame_dirty(g.raw(), &r) <= 0) return null;
        return r;
    }

    /// Copies the last frame (or `area`, real px) into `dst` in the given format. `dst_stride` is in bytes.
    pub fn frameCopy(g: *Goome, dst: []u8, dst_stride: usize, format: Format, area: ?Rect) Error!void {
        const fr = try g.frame();
        const w: usize = if (area) |a| @intCast(a.w) else fr.width();
        const h: usize = if (area) |a| @intCast(a.h) else fr.height();
        if (h > 0 and dst.len < (h - 1) * dst_stride + w * 4) return error.BadArgument;
        const r: [*c]const Rect = if (area) |*a| a else null;
        try check(c.goome_frame_copy(g.raw(), dst.ptr, @intCast(dst_stride), @intFromEnum(format), r));
    }

    /// Makes a `Ui` for this instance. Free it with `Ui.deinit`.
    pub fn ui(g: *Goome) Error!*Ui {
        const u = c.goome_ui_new(g.raw()) orelse return error.OutOfMemory;
        return @ptrCast(u);
    }
};

/// What you draw on, from `Goome.begin` or `Ui.begin`. Coords are logical, the canvas scales them.
pub const Canvas = opaque {
    /// The C canvas.
    pub fn raw(cv: *Canvas) *c.goome_canvas {
        return @ptrCast(@alignCast(cv));
    }

    /// Width in real px.
    pub fn width(cv: *Canvas) usize {
        return @intCast(cv.raw().w);
    }

    /// Height in real px.
    pub fn height(cv: *Canvas) usize {
        return @intCast(cv.raw().h);
    }

    /// Row length in pixels.
    pub fn stride(cv: *Canvas) usize {
        return @intCast(cv.raw().stride);
    }

    /// Real px per logical px.
    pub fn scale(cv: *Canvas) f64 {
        return cv.raw().scale;
    }

    /// All the pixels, premultiplied argb.
    pub fn pixels(cv: *Canvas) []u32 {
        const r = cv.raw();
        if (r.px == null) return &.{};
        return r.px[0 .. cv.height() * cv.stride()];
    }

    /// Marks a rect as drawn on by hand. Null means everything. Only needed if you write to `pixels` yourself.
    pub fn damage(cv: *Canvas, r: ?Rect) void {
        const p: [*c]const Rect = if (r) |*a| a else null;
        c.goome_damage(cv.raw(), p);
    }

    /// Wipes the canvas.
    pub fn clear(cv: *Canvas) void {
        c.goome_clear(cv.raw());
    }

    /// Filled rectangle.
    pub fn rect(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, argb: u32) void {
        c.goome_draw_rect(cv.raw(), x, y, w, h, argb);
    }

    /// Filled rectangle with the same radius on every corner.
    pub fn roundRect(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, r: f64, argb: u32) void {
        c.goome_draw_round_rect(cv.raw(), x, y, w, h, r, argb);
    }

    /// Rectangle outline, `line_w` thick.
    pub fn frame(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, line_w: f64, argb: u32) void {
        c.goome_draw_frame(cv.raw(), x, y, w, h, line_w, argb);
    }

    /// A line, `line_w` thick.
    pub fn line(cv: *Canvas, x0: f64, y0: f64, x1: f64, y1: f64, line_w: f64, argb: u32) void {
        c.goome_draw_line(cv.raw(), x0, y0, x1, y1, line_w, argb);
    }

    /// Filled triangle.
    pub fn triangle(cv: *Canvas, x0: f64, y0: f64, x1: f64, y1: f64, x2: f64, y2: f64, argb: u32) void {
        c.goome_draw_triangle(cv.raw(), x0, y0, x1, y1, x2, y2, argb);
    }

    /// Draws plain argb pixels scaled into x y w h. Skipped if `px` is too small.
    pub fn image(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, px: []const u32, iw: usize, ih: usize) void {
        if (px.len < iw * ih) return;
        c.goome_draw_image(cv.raw(), x, y, w, h, px.ptr, @intCast(iw), @intCast(ih));
    }

    /// Makes a rect fully transparent.
    pub fn erase(cv: *Canvas, x: f64, y: f64, w: f64, h: f64) void {
        c.goome_erase(cv.raw(), x, y, w, h);
    }

    /// Draws text with the built in font, `big` for the larger size. Gives back the width.
    pub fn text(cv: *Canvas, x: f64, y: f64, s: [*:0]const u8, big: bool, argb: u32) f64 {
        return c.goome_draw_text(cv.raw(), x, y, s, cb(big), argb);
    }

    /// Width the built in font would give the text.
    pub fn textWidth(cv: *Canvas, s: [*:0]const u8, big: bool) f64 {
        return c.goome_text_width(cv.raw(), s, cb(big));
    }

    /// Draws another canvas on this one, `alpha` 0 to 1, offset by dx and dy.
    pub fn blit(cv: *Canvas, src: *Canvas, alpha: f64, dx: f64, dy: f64) void {
        c.goome_canvas_blit(cv.raw(), src.raw(), alpha, dx, dy);
    }

    /// Clips drawing to a rect. Snaps to whole px, 16 deep, `Goome.begin` resets it.
    pub fn clipPush(cv: *Canvas, x: f64, y: f64, w: f64, h: f64) void {
        c.goome_clip_push(cv.raw(), x, y, w, h);
    }

    /// Undoes the last `clipPush`.
    pub fn clipPop(cv: *Canvas) void {
        c.goome_clip_pop(cv.raw());
    }

    /// Filled rounded rect with a radius per corner.
    pub fn rrect(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, r: Radii, argb: u32) void {
        c.goome_draw_rrect(cv.raw(), x, y, w, h, r, argb);
    }

    /// Rounded rect outline with a radius per corner.
    pub fn rrectLine(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, r: Radii, line_w: f64, argb: u32) void {
        c.goome_draw_rrect_line(cv.raw(), x, y, w, h, r, line_w, argb);
    }

    /// Rounded rect filled with a gradient from `from` to `to`. `sideways` makes it go left to right instead of top to bottom.
    pub fn rrectGrad(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, r: Radii, from: u32, to: u32, sideways: bool) void {
        c.goome_draw_rrect_grad(cv.raw(), x, y, w, h, r, from, to, cb(sideways));
    }

    /// Soft shadow under a rounded rect, `blur` works like css box-shadow.
    pub fn shadow(cv: *Canvas, x: f64, y: f64, w: f64, h: f64, r: f64, blur: f64, argb: u32) void {
        c.goome_draw_shadow(cv.raw(), x, y, w, h, r, blur, argb);
    }

    /// Filled circle.
    pub fn circle(cv: *Canvas, cx: f64, cy: f64, r: f64, argb: u32) void {
        c.goome_draw_circle(cv.raw(), cx, cy, r, argb);
    }

    /// Circle outline. `r` is the middle of the stroke.
    pub fn ring(cv: *Canvas, cx: f64, cy: f64, r: f64, line_w: f64, argb: u32) void {
        c.goome_draw_ring(cv.raw(), cx, cy, r, line_w, argb);
    }

    /// Arc outline. Angles are radians, 0 is 3 oclock and it goes clockwise, with round caps.
    pub fn arc(cv: *Canvas, cx: f64, cy: f64, r: f64, line_w: f64, a0: f64, a1: f64, argb: u32) void {
        c.goome_draw_arc(cv.raw(), cx, cy, r, line_w, a0, a1, argb);
    }

    /// Filled polygon from x,y points, nonzero fill.
    pub fn poly(cv: *Canvas, points: []const [2]f64, argb: u32) void {
        c.goome_draw_poly(cv.raw(), @ptrCast(points.ptr), @intCast(points.len), argb);
    }

    /// Draws a bitmap into x y w h with rounded corners. `tint` is multiplied in.
    pub fn bitmap(cv: *Canvas, b: *const Bitmap, x: f64, y: f64, w: f64, h: f64, r: Radii, tint: u32) void {
        c.goome_draw_bitmap(cv.raw(), &b.raw, x, y, w, h, r, tint);
    }

    /// Draws the sx sy sw sh part of a bitmap (bitmap px) into x y w h.
    pub fn bitmapPart(cv: *Canvas, b: *const Bitmap, sx: i32, sy: i32, sw: i32, sh: i32, x: f64, y: f64, w: f64, h: f64, tint: u32) void {
        c.goome_draw_bitmap_part(cv.raw(), &b.raw, sx, sy, sw, sh, x, y, w, h, tint);
    }

    /// Draws a bitmap as a nine-slice. `l`, `t`, `r` and `bm` are the border sizes in bitmap px.
    pub fn bitmapNine(cv: *Canvas, b: *const Bitmap, x: f64, y: f64, w: f64, h: f64, l: f64, t: f64, r: f64, bm: f64) void {
        c.goome_draw_bitmap_nine(cv.raw(), &b.raw, x, y, w, h, l, t, r, bm);
    }

    /// Draws text with a font, `y` is the top. Null font means the built in one. Gives back the width.
    pub fn fontText(cv: *Canvas, f: ?*Font, size: f64, x: f64, y: f64, s: [*:0]const u8, argb: u32) f64 {
        return c.goome_text(cv.raw(), Font.ptr(f), size, x, y, s, argb);
    }
};

/// A canvas that owns its pixel buffer, for drawing without a `Goome`.
pub const OwnedCanvas = struct {
    raw: c.goome_canvas,
    buf: []u32,
    allocator: std.mem.Allocator,

    /// Allocates and zeroes a canvas. `row_stride` is in pixels and has to be at least `w`.
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

    /// Frees the pixel buffer.
    pub fn deinit(o: *OwnedCanvas) void {
        o.allocator.free(o.buf);
        o.buf = &.{};
        o.raw.px = null;
    }

    /// The `Canvas` to draw on.
    pub fn canvas(o: *OwnedCanvas) *Canvas {
        return @ptrCast(&o.raw);
    }
};

/// Why the last bitmap load failed.
pub fn bitmapError() [:0]const u8 {
    return span(c.goome_bitmap_error()) orelse "";
}

/// An image with premultiplied argb pixels, for drawing and ui images.
pub const Bitmap = struct {
    raw: c.goome_bitmap = .{},

    /// Loads png, jpeg, bmp, ppm or qoi. Picks by content, not file name.
    pub fn load(path: [*:0]const u8) Error!Bitmap {
        var b: Bitmap = .{};
        try check(c.goome_bitmap_load(path, &b.raw));
        return b;
    }

    /// Same as `load` but from bytes in memory.
    pub fn loadMem(data: []const u8) Error!Bitmap {
        var b: Bitmap = .{};
        try check(c.goome_bitmap_load_mem(data.ptr, data.len, &b.raw));
        return b;
    }

    /// Makes a bitmap from plain (not premultiplied) argb pixels. They get copied.
    pub fn fromArgb(argb: []const u32, w: usize, h: usize) Error!Bitmap {
        if (argb.len < w * h) return error.BadArgument;
        var b: Bitmap = .{};
        try check(c.goome_bitmap_from_argb(argb.ptr, @intCast(w), @intCast(h), &b.raw));
        return b;
    }

    /// Wraps pixels you already own, no copy and `deinit` wont free them. They have to be premultiplied argb.
    pub fn wrap(px: []u32, w: usize, h: usize, row_stride: usize) Bitmap {
        return .{ .raw = .{ .px = px.ptr, .w = @intCast(w), .h = @intCast(h), .stride = @intCast(row_stride), .owned = 0 } };
    }

    /// Frees the pixels if the bitmap owns them.
    pub fn deinit(b: *Bitmap) void {
        c.goome_bitmap_free(&b.raw);
        b.raw = .{};
    }

    /// Width in px.
    pub fn width(b: Bitmap) usize {
        return @intCast(b.raw.w);
    }

    /// Height in px.
    pub fn height(b: Bitmap) usize {
        return @intCast(b.raw.h);
    }

    /// Row length in pixels.
    pub fn stride(b: Bitmap) usize {
        return @intCast(b.raw.stride);
    }

    /// True if `deinit` frees the pixels.
    pub fn owned(b: Bitmap) bool {
        return b.raw.owned != 0;
    }

    /// All the pixels.
    pub fn pixels(b: Bitmap) []u32 {
        if (b.raw.px == null) return &.{};
        return b.raw.px[0 .. b.height() * b.stride()];
    }
};

/// Picks which built in font `Canvas.text` uses.
pub fn setFont(font: i32) void {
    c.goome_set_font(font);
}

/// How many built in fonts there are.
pub fn fontCount() i32 {
    return c.goome_font_count();
}

/// Width and height of measured text.
pub const Size = struct { w: f64, h: f64 };

/// Size of text with the built in font.
pub fn measure(size: f64, s: [*:0]const u8) Size {
    return Font.measureWith(null, size, s);
}

/// Line height of the built in font at this size.
pub fn lineHeight(size: f64) f64 {
    return c.goome_text_line_height(null, size);
}

/// A loaded font. Use with `Canvas.fontText` or `Ui.pushFont`. A null font means the built in one.
pub const Font = opaque {
    fn ptr(f: ?*Font) ?*c.goome_font {
        return @ptrCast(f);
    }

    fn wrapPtr(p: ?*c.goome_font) Error!*Font {
        return @ptrCast(p orelse return error.LoadFailed);
    }

    /// Loads a .ttf, .otf or .ttc file.
    pub fn load(path: [*:0]const u8) Error!*Font {
        return wrapPtr(c.goome_font_load(path));
    }

    /// Loads one face out of a .ttc. Fontconfig hands these out.
    pub fn loadIndex(path: [*:0]const u8, index: i32) Error!*Font {
        return wrapPtr(c.goome_font_load_index(path, index));
    }

    /// Loads a font from memory. With `copy` false the data has to stay alive as long as the font.
    pub fn loadMem(data: []const u8, copy: bool) Error!*Font {
        return wrapPtr(c.goome_font_load_mem(data.ptr, data.len, cb(copy)));
    }

    /// The system font by name. Null name means the desktops usual ui font. Null if it cant be found.
    pub fn system(name: ?[*:0]const u8) ?*Font {
        return @ptrCast(c.goome_font_system(cstr(name)));
    }

    /// Frees the font.
    pub fn deinit(f: *Font) void {
        c.goome_font_free(ptr(f));
    }

    fn measureWith(f: ?*Font, size: f64, s: [*:0]const u8) Size {
        var h: f64 = 0;
        const w = c.goome_text_measure(ptr(f), size, s, &h);
        return .{ .w = w, .h = h };
    }

    /// Size of text at this font size.
    pub fn measure(f: *Font, size: f64, s: [*:0]const u8) Size {
        return measureWith(f, size, s);
    }

    /// Width of text at this font size.
    pub fn width(f: *Font, size: f64, s: [*:0]const u8) f64 {
        return measureWith(f, size, s).w;
    }

    /// Line height at this font size.
    pub fn lineHeight(f: *Font, size: f64) f64 {
        return c.goome_text_line_height(ptr(f), size);
    }

    /// Sets a font to try, in order, for chars this one doesnt have. This font doesnt free it. `system` adds the emoji font by itself.
    pub fn fallback(f: *Font, other: *Font) void {
        c.goome_font_fallback(ptr(f), ptr(other));
    }
};

/// State of a ui window. Pass it to `Ui.window` and the ui moves and resizes it for you.
pub const Window = extern struct {
    /// Left edge, logical.
    x: f64 = 40,
    /// Top edge, logical.
    y: f64 = 40,
    /// Width, logical.
    w: f64 = 300,
    /// Height, logical. 0 means fit the content.
    h: f64 = 0,
    /// 1 while the window is open, the close button sets it to 0.
    open: c_int = 1,

    /// True while open.
    pub fn isOpen(w: *const Window) bool {
        return w.open != 0;
    }

    /// Opens or closes it.
    pub fn setOpen(w: *Window, on: bool) void {
        w.open = cb(on);
    }
};

/// Rows `Ui.listClip` says to draw, `first` up to `last`.
pub const ListRange = struct { first: usize, last: usize };

fn items(list: []const [*:0]const u8) [*c]const [*c]const u8 {
    return @ptrCast(list.ptr);
}

/// The widget kit. Make one with `Goome.ui`, then each frame call `begin`, your widgets, then `end`. Widgets that return bool say if something happened this frame.
pub const Ui = opaque {
    /// The C ui.
    pub fn raw(u: *Ui) *c.goome_ui {
        return @ptrCast(u);
    }

    /// Frees the ui.
    pub fn deinit(u: *Ui) void {
        c.goome_ui_free(u.raw());
    }

    /// The theme to change in place.
    pub fn theme(u: *Ui) *Theme {
        return c.goome_ui_theme(u.raw());
    }

    /// Sets the theme to the dark colors. Leaves the font alone.
    pub fn themeDark(u: *Ui) void {
        c.goome_ui_theme_dark(u.theme());
    }

    /// Sets the theme to the light colors. Leaves the font alone.
    pub fn themeLight(u: *Ui) void {
        c.goome_ui_theme_light(u.theme());
    }

    /// Builds a theme from an accent color, dark or light, and a corner radius.
    pub fn themeMake(u: *Ui, accent: u32, dark: bool, r: f64) void {
        c.goome_ui_theme_make(u.theme(), accent, cb(dark), r);
    }

    /// Loads one of the GOOME_PRESET_* themes.
    pub fn themePreset(u: *Ui, preset: c_int) Error!void {
        try check(c.goome_ui_theme_preset(u.theme(), preset));
    }

    /// Scales the whole ui.
    pub fn scale(u: *Ui, s: f64) void {
        c.goome_ui_scale(u.raw(), s);
    }

    /// The behavior settings to change in place.
    pub fn config(u: *Ui) *UiConfig {
        return c.goome_ui_cfg(u.raw());
    }

    /// Binds a GOOME_ACT_* action to key combos, like "ctrl+c".
    pub fn bind(u: *Ui, act: c_int, combos: [*:0]const u8) Error!void {
        try check(c.goome_ui_bind(u.raw(), act, combos));
    }

    /// Gives the ui an event. True if it used it.
    pub fn feed(u: *Ui, ev: Event) bool {
        return c.goome_ui_feed(u.raw(), ev.raw()) > 0;
    }

    /// Starts a ui frame. Null means nothing to draw on, skip the frame.
    pub fn begin(u: *Ui, mon: i32) ?*Canvas {
        const cv = c.goome_ui_begin(u.raw(), mon);
        if (cv == null) return null;
        return @ptrCast(cv);
    }

    /// Sends the frame with every widgets hit area.
    pub fn end(u: *Ui) void {
        c.goome_ui_end(u.raw());
    }

    /// Adds your own hit rect, for stuff you drew straight on the canvas.
    pub fn hit(u: *Ui, x: f64, y: f64, w: f64, h: f64) void {
        c.goome_ui_hit(u.raw(), x, y, w, h);
    }

    /// True while something still moves, draw again soon.
    pub fn animating(u: *Ui) bool {
        return c.goome_ui_animating(u.raw()) != 0;
    }

    /// Bits from `want`. Good after `feed` and `end`.
    pub fn wants(u: *Ui) c_int {
        return c.goome_ui_wants(u.raw());
    }

    /// True if the ui wants the mouse.
    pub fn wantsMouse(u: *Ui) bool {
        return u.wants() & c.GOOME_WANT_MOUSE != 0;
    }

    /// True if the ui wants the keyboard.
    pub fn wantsKeyboard(u: *Ui) bool {
        return u.wants() & c.GOOME_WANT_KEYBOARD != 0;
    }

    /// Which `want` bits the ui takes from the os by itself. Default is both, 0 means the app does it.
    pub fn autoGrab(u: *Ui, w: c_int) void {
        c.goome_ui_auto_grab(u.raw(), w);
    }

    /// Starts a window, `flags` are from `win`. True while its open and not collapsed. Always call `windowEnd`.
    pub fn window(u: *Ui, title: [*:0]const u8, w: *Window, flags: c_int) bool {
        return c.goome_ui_window(u.raw(), title, &w.x, &w.y, &w.w, &w.h, flags, &w.open) != 0;
    }

    /// Ends a window.
    pub fn windowEnd(u: *Ui) void {
        c.goome_ui_window_end(u.raw());
    }

    /// Lays the next widgets out in this many columns. 1 or less goes back to normal flow.
    pub fn row(u: *Ui, cols: i32) void {
        c.goome_ui_row(u.raw(), cols);
    }

    /// Puts the next widget on the same line.
    pub fn sameLine(u: *Ui) void {
        c.goome_ui_same_line(u.raw());
    }

    /// Adds empty space in px.
    pub fn space(u: *Ui, px: f64) void {
        c.goome_ui_space(u.raw(), px);
    }

    /// Draws a divider line.
    pub fn separator(u: *Ui) void {
        c.goome_ui_separator(u.raw());
    }

    /// Width of the next widget, 0 means fill.
    pub fn width(u: *Ui, w: f64) void {
        c.goome_ui_width(u.raw(), w);
    }

    /// Plain text.
    pub fn label(u: *Ui, s: [*:0]const u8) void {
        c.goome_ui_label(u.raw(), "%s", s);
    }

    /// Text from a Zig format string, cut at 511 bytes.
    pub fn labelFmt(u: *Ui, comptime fmt: []const u8, args: anytype) void {
        var buf: [512]u8 = undefined;
        const s = std.fmt.bufPrintZ(&buf, fmt, args) catch blk: {
            buf[buf.len - 1] = 0;
            break :blk buf[0 .. buf.len - 1 :0];
        };
        u.label(s.ptr);
    }

    /// Bigger text.
    pub fn heading(u: *Ui, s: [*:0]const u8) void {
        c.goome_ui_heading(u.raw(), s);
    }

    /// Text that wraps to the width.
    pub fn wrapped(u: *Ui, s: [*:0]const u8) void {
        c.goome_ui_wrapped(u.raw(), s);
    }

    /// A button, true when clicked.
    pub fn button(u: *Ui, s: [*:0]const u8) bool {
        return c.goome_ui_button(u.raw(), s) != 0;
    }

    /// A button with a bitmap. `id` tells it apart from other buttons. True when clicked.
    pub fn imageButton(u: *Ui, id: [*:0]const u8, b: *const Bitmap, w: f64, h: f64) bool {
        return c.goome_ui_image_button(u.raw(), id, &b.raw, w, h) != 0;
    }

    /// Shows a bitmap, `r` is the corner radius.
    pub fn image(u: *Ui, b: *const Bitmap, w: f64, h: f64, r: f64) void {
        c.goome_ui_image(u.raw(), &b.raw, w, h, r);
    }

    /// A checkbox, true when it changed.
    pub fn checkbox(u: *Ui, s: [*:0]const u8, v: *bool) bool {
        var t: c_int = cb(v.*);
        const r = c.goome_ui_checkbox(u.raw(), s, &t);
        v.* = t != 0;
        return r != 0;
    }

    /// A toggle switch, true when it changed.
    pub fn toggle(u: *Ui, s: [*:0]const u8, v: *bool) bool {
        var t: c_int = cb(v.*);
        const r = c.goome_ui_toggle(u.raw(), s, &t);
        v.* = t != 0;
        return r != 0;
    }

    /// A radio button. Sets `v` to `value` when clicked, true when it changed.
    pub fn radio(u: *Ui, s: [*:0]const u8, v: *i32, value: i32) bool {
        return c.goome_ui_radio(u.raw(), s, @ptrCast(v), value) != 0;
    }

    /// A slider from `min` to `max`. `fmt` is a printf format for the value, null for the default. True when it changed.
    pub fn slider(u: *Ui, s: [*:0]const u8, v: *f64, min: f64, max: f64, fmt: ?[*:0]const u8) bool {
        return c.goome_ui_slider(u.raw(), s, v, min, max, cstr(fmt)) != 0;
    }

    /// Integer slider from `min` to `max`. True when it changed.
    pub fn sliderInt(u: *Ui, s: [*:0]const u8, v: *i32, min: i32, max: i32) bool {
        return c.goome_ui_slider_int(u.raw(), s, @ptrCast(v), min, max) != 0;
    }

    /// A one line text input that edits `buf` in place. True when the text changed.
    pub fn input(u: *Ui, s: [*:0]const u8, buf: []u8) bool {
        if (buf.len == 0) return false;
        return c.goome_ui_input(u.raw(), s, buf.ptr, @intCast(buf.len)) != 0;
    }

    /// Text input with GOOME_INPUT_* flags and a hint shown while its empty.
    pub fn inputEx(u: *Ui, s: [*:0]const u8, buf: []u8, flags: c_int, hint: ?[*:0]const u8) bool {
        if (buf.len == 0) return false;
        return c.goome_ui_input_ex(u.raw(), s, buf.ptr, @intCast(buf.len), flags, cstr(hint)) != 0;
    }

    /// A dropdown over `list`, `sel` is the picked index. True when it changed.
    pub fn combo(u: *Ui, s: [*:0]const u8, sel: *i32, list: []const [*:0]const u8) bool {
        return c.goome_ui_combo(u.raw(), s, @ptrCast(sel), items(list), @intCast(list.len)) != 0;
    }

    /// A row you can select, true when clicked.
    pub fn selectable(u: *Ui, s: [*:0]const u8, selected: bool) bool {
        return c.goome_ui_selectable(u.raw(), s, cb(selected)) != 0;
    }

    /// A tab bar, `sel` is the picked tab. True when it changed.
    pub fn tabs(u: *Ui, id: [*:0]const u8, names: []const [*:0]const u8, sel: *i32) bool {
        return c.goome_ui_tabs(u.raw(), id, items(names), @intCast(names.len), @ptrCast(sel)) != 0;
    }

    /// A collapsing header. True while open. Pass null for `open` to let the ui remember it.
    pub fn collapsing(u: *Ui, s: [*:0]const u8, open: ?*bool) bool {
        if (open) |o| {
            var t: c_int = cb(o.*);
            const r = c.goome_ui_collapsing(u.raw(), s, &t);
            o.* = t != 0;
            return r != 0;
        }
        return c.goome_ui_collapsing(u.raw(), s, null) != 0;
    }

    /// A progress bar, `frac` from 0 to 1. `s` is the text on it, null for none.
    pub fn progress(u: *Ui, frac: f64, s: ?[*:0]const u8) void {
        c.goome_ui_progress(u.raw(), frac, cstr(s));
    }

    /// A color picker that edits `argb`. True when it changed.
    pub fn color(u: *Ui, s: [*:0]const u8, argb: *u32) bool {
        return c.goome_ui_color(u.raw(), s, argb) != 0;
    }

    /// Tooltip for the widget right before it.
    pub fn tooltip(u: *Ui, s: [*:0]const u8) void {
        c.goome_ui_tooltip(u.raw(), s);
    }

    /// True if the widget right before it is hovered.
    pub fn hovered(u: *Ui) bool {
        return c.goome_ui_hovered(u.raw()) != 0;
    }

    /// Starts a scroll area `h` tall. Always call `scrollEnd`.
    pub fn scrollBegin(u: *Ui, id: [*:0]const u8, h: f64) bool {
        return c.goome_ui_scroll_begin(u.raw(), id, h) != 0;
    }

    /// Ends a scroll area.
    pub fn scrollEnd(u: *Ui) void {
        c.goome_ui_scroll_end(u.raw());
    }

    /// Pushes an id. Use it for the same labels in a loop, push the index first.
    pub fn pushId(u: *Ui, id: [*:0]const u8) void {
        c.goome_ui_push_id(u.raw(), id);
    }

    /// Same as `pushId` with a number, handy in loops.
    pub fn pushIndex(u: *Ui, i: usize) void {
        var buf: [24]u8 = undefined;
        const s = std.fmt.bufPrintZ(&buf, "{d}", .{i}) catch unreachable;
        u.pushId(s.ptr);
    }

    /// Pops the last id.
    pub fn popId(u: *Ui) void {
        c.goome_ui_pop_id(u.raw());
    }

    /// Root panel that fills monitor 0, call it after `begin`. `flags` are GOOME_APP_*. Always call `appEnd`.
    pub fn app(u: *Ui, title: ?[*:0]const u8, flags: c_int) bool {
        return c.goome_ui_app(u.raw(), cstr(title), flags) != 0;
    }

    /// Ends the app panel.
    pub fn appEnd(u: *Ui) void {
        c.goome_ui_app_end(u.raw());
    }

    /// Starts the menu bar. Needs GOOME_APP_MENUBAR.
    pub fn menubarBegin(u: *Ui) bool {
        return c.goome_ui_menubar_begin(u.raw()) != 0;
    }

    /// Ends the menu bar.
    pub fn menubarEnd(u: *Ui) void {
        c.goome_ui_menubar_end(u.raw());
    }

    /// Starts a menu. True while open, nest for submenus. Call `menuEnd` after.
    pub fn menuBegin(u: *Ui, s: [*:0]const u8) bool {
        return c.goome_ui_menu_begin(u.raw(), s) != 0;
    }

    /// Ends a menu.
    pub fn menuEnd(u: *Ui) void {
        c.goome_ui_menu_end(u.raw());
    }

    /// A menu entry, true when clicked. `shortcut` is just shown, `checked` can be null.
    pub fn menuItem(u: *Ui, s: [*:0]const u8, shortcut: ?[*:0]const u8, checked: ?*bool) bool {
        if (checked) |ch| {
            var t: c_int = cb(ch.*);
            const r = c.goome_ui_menu_item(u.raw(), s, cstr(shortcut), &t);
            ch.* = t != 0;
            return r != 0;
        }
        return c.goome_ui_menu_item(u.raw(), s, cstr(shortcut), null) != 0;
    }

    /// Divider in a menu.
    pub fn menuSeparator(u: *Ui) void {
        c.goome_ui_menu_separator(u.raw());
    }

    /// Context menu, opened by a right click on the widget before it (or empty space). True while open.
    pub fn contextBegin(u: *Ui, id: [*:0]const u8) bool {
        return c.goome_ui_context_begin(u.raw(), id) != 0;
    }

    /// Ends a context menu.
    pub fn contextEnd(u: *Ui) void {
        c.goome_ui_context_end(u.raw());
    }

    /// Opens a popup by id.
    pub fn popupOpen(u: *Ui, id: [*:0]const u8) void {
        c.goome_ui_popup_open(u.raw(), id);
    }

    /// Starts a popup. True while its open, then call `popupEnd`.
    pub fn popupBegin(u: *Ui, id: [*:0]const u8) bool {
        return c.goome_ui_popup_begin(u.raw(), id) != 0;
    }

    /// Ends a popup.
    pub fn popupEnd(u: *Ui) void {
        c.goome_ui_popup_end(u.raw());
    }

    /// Closes the innermost open popup, menu or modal.
    pub fn popupClose(u: *Ui) void {
        c.goome_ui_popup_close(u.raw());
    }

    /// A centered dialog that dims the rest, esc closes it. True while open, then call `modalEnd`.
    pub fn modalBegin(u: *Ui, title: [*:0]const u8, open: ?*c_int) bool {
        return c.goome_ui_modal_begin(u.raw(), title, open) != 0;
    }

    /// Ends a modal.
    pub fn modalEnd(u: *Ui) void {
        c.goome_ui_modal_end(u.raw());
    }

    /// Shows a short message for `ms` milliseconds.
    pub fn toast(u: *Ui, s: [*:0]const u8, ms: i32) void {
        c.goome_ui_toast(u.raw(), s, ms);
    }

    /// Text in the status bar. Needs GOOME_APP_STATUSBAR.
    pub fn statusbar(u: *Ui, s: [*:0]const u8) void {
        c.goome_ui_statusbar(u.raw(), s);
    }

    /// True if the widget right before it has keyboard focus.
    pub fn focused(u: *Ui) bool {
        return c.goome_ui_focused(u.raw()) != 0;
    }

    /// Gives focus to the next widget.
    pub fn setFocus(u: *Ui) void {
        c.goome_ui_set_focus(u.raw());
    }

    /// Multiline editor over `buf`, `h` tall, with GOOME_EDIT_* flags. True when the text changed.
    pub fn textEdit(u: *Ui, id: [*:0]const u8, buf: []u8, h: f64, flags: c_int) bool {
        if (buf.len == 0) return false;
        return c.goome_ui_text_edit(u.raw(), id, buf.ptr, @intCast(buf.len), h, flags) != 0;
    }

    /// Starts a table, `flags` are GOOME_TABLE_*. Add the columns next. True while visible, then call `tableEnd`.
    pub fn tableBegin(u: *Ui, id: [*:0]const u8, cols: i32, h: f64, flags: c_int) bool {
        return c.goome_ui_table_begin(u.raw(), id, cols, h, flags) != 0;
    }

    /// Adds a column. Width 0 shares the rest.
    pub fn tableColumn(u: *Ui, name: [*:0]const u8, w: f64) void {
        c.goome_ui_table_column(u.raw(), name, w);
    }

    /// True if the sort changed this frame, call it after the columns. Gives you the column and direction.
    pub fn tableSort(u: *Ui, col: *i32, desc: *bool) bool {
        var d: c_int = cb(desc.*);
        const r = c.goome_ui_table_sort(u.raw(), @ptrCast(col), &d);
        desc.* = d != 0;
        return r != 0;
    }

    /// Starts a new row.
    pub fn tableRow(u: *Ui) void {
        c.goome_ui_table_row(u.raw());
    }

    /// Moves to the next cell.
    pub fn tableNext(u: *Ui) void {
        c.goome_ui_table_next(u.raw());
    }

    /// Ends a table.
    pub fn tableEnd(u: *Ui) void {
        c.goome_ui_table_end(u.raw());
    }

    /// A tree node. True while open, then call `treeEnd`. Pass null for `open` to let the ui remember it.
    pub fn tree(u: *Ui, s: [*:0]const u8, open: ?*bool) bool {
        if (open) |o| {
            var t: c_int = cb(o.*);
            const r = c.goome_ui_tree(u.raw(), s, &t);
            o.* = t != 0;
            return r != 0;
        }
        return c.goome_ui_tree(u.raw(), s, null) != 0;
    }

    /// Ends an open tree node.
    pub fn treeEnd(u: *Ui) void {
        c.goome_ui_tree_end(u.raw());
    }

    /// Inside a scroll area, tells you which rows to draw, so a huge list stays cheap.
    pub fn listClip(u: *Ui, count: usize, row_h: f64) ListRange {
        var first: c_int = 0;
        var last: c_int = 0;
        _ = c.goome_ui_list_clip(u.raw(), @intCast(count), row_h, &first, &last);
        const f: usize = @intCast(@max(0, first));
        const l: usize = @intCast(@max(first, last));
        return .{ .first = f, .last = l };
    }

    /// A number you change by dragging. True when it changed.
    pub fn dragFloat(u: *Ui, s: [*:0]const u8, v: *f64, speed: f64, min: f64, max: f64, fmt: ?[*:0]const u8) bool {
        return c.goome_ui_drag_float(u.raw(), s, v, speed, min, max, cstr(fmt)) != 0;
    }

    /// An integer you change by dragging. True when it changed.
    pub fn dragInt(u: *Ui, s: [*:0]const u8, v: *i32, speed: f64, min: i32, max: i32) bool {
        return c.goome_ui_drag_int(u.raw(), s, @ptrCast(v), speed, min, max) != 0;
    }

    /// A number field with step buttons. True when it changed.
    pub fn number(u: *Ui, s: [*:0]const u8, v: *f64, step: f64, fmt: ?[*:0]const u8) bool {
        return c.goome_ui_number(u.raw(), s, v, step, cstr(fmt)) != 0;
    }

    /// Line graph of `v`, `h` tall, scaled between `min` and `max`.
    pub fn plotLines(u: *Ui, s: [*:0]const u8, v: []const f32, min: f64, max: f64, h: f64) void {
        c.goome_ui_plot_lines(u.raw(), s, v.ptr, @intCast(v.len), min, max, h);
    }

    /// Bar graph of `v`, `h` tall, scaled between `min` and `max`.
    pub fn plotBars(u: *Ui, s: [*:0]const u8, v: []const f32, min: f64, max: f64, h: f64) void {
        c.goome_ui_plot_bars(u.raw(), s, v.ptr, @intCast(v.len), min, max, h);
    }

    /// Splits the space in two, `frac` is how much the first part gets. True while visible, then `splitNext` and `splitEnd`.
    pub fn splitBegin(u: *Ui, id: [*:0]const u8, vertical: bool, frac: *f64) bool {
        return c.goome_ui_split_begin(u.raw(), id, cb(vertical), frac) != 0;
    }

    /// Switches to the second part of a split.
    pub fn splitNext(u: *Ui) void {
        c.goome_ui_split_next(u.raw());
    }

    /// Ends a split.
    pub fn splitEnd(u: *Ui) void {
        c.goome_ui_split_end(u.raw());
    }

    /// Makes the widget before it draggable, carrying `data`. `kind` has to match the drop target.
    pub fn dragSource(u: *Ui, kind: [*:0]const u8, data: []const u8) bool {
        return c.goome_ui_drag_source(u.raw(), kind, data.ptr, @intCast(data.len)) != 0;
    }

    /// Makes the widget before it take drops of this `kind`. Gives back the dropped bytes, null if nothing.
    pub fn dropTarget(u: *Ui, kind: [*:0]const u8, buf: []u8) ?[]u8 {
        const n = c.goome_ui_drop_target(u.raw(), kind, buf.ptr, @intCast(buf.len));
        if (n <= 0) return null;
        return buf[0..@min(buf.len, @as(usize, @intCast(n)))];
    }

    /// A loading spinner, `sz` px wide.
    pub fn spinner(u: *Ui, sz: f64) void {
        c.goome_ui_spinner(u.raw(), sz);
    }

    /// A link looking text, true when clicked.
    pub fn link(u: *Ui, s: [*:0]const u8) bool {
        return c.goome_ui_link(u.raw(), s) != 0;
    }

    /// A small colored tag.
    pub fn badge(u: *Ui, s: [*:0]const u8, argb: u32) void {
        c.goome_ui_badge(u.raw(), s, argb);
    }

    /// Puts the next widget at x,y from the content top left (scroll included). The flow doesnt move.
    pub fn pos(u: *Ui, x: f64, y: f64) void {
        c.goome_ui_pos(u.raw(), x, y);
    }

    /// Size of the next widget, 0 means its own size for that side.
    pub fn size(u: *Ui, w: f64, h: f64) void {
        c.goome_ui_size(u.raw(), w, h);
    }

    /// Overrides a color (GOOME_S_*) until popped.
    pub fn pushColor(u: *Ui, what: c_int, argb: u32) void {
        c.goome_ui_push_color(u.raw(), what, argb);
    }

    /// Overrides a number (GOOME_S_*) until popped.
    pub fn pushNum(u: *Ui, what: c_int, v: f64) void {
        c.goome_ui_push_num(u.raw(), what, v);
    }

    /// Overrides the corner radius per corner until popped. Beats GOOME_S_RADIUS.
    pub fn pushRadii(u: *Ui, r: Radii) void {
        c.goome_ui_push_radii(u.raw(), r);
    }

    /// Overrides the font until popped. Null means the built in one.
    pub fn pushFont(u: *Ui, f: ?*Font) void {
        c.goome_ui_push_font(u.raw(), Font.ptr(f));
    }

    /// Overrides a skin (GOOME_SKIN_*) until popped. Null means no skin.
    pub fn pushSkin(u: *Ui, kind: c_int, s: ?*const Skin) void {
        c.goome_ui_push_skin(u.raw(), kind, s);
    }

    /// Swaps in a whole theme until popped.
    pub fn pushTheme(u: *Ui, t: *const Theme) void {
        c.goome_ui_push_theme(u.raw(), t);
    }

    /// Overrides one of the GOOME_ICON_* bitmaps until popped.
    pub fn pushIcon(u: *Ui, icon: c_int, b: ?*const Bitmap) void {
        c.goome_ui_push_icon(u.raw(), icon, if (b) |bm| &bm.raw else null);
    }

    /// Pops the last `n` pushes, of any kind.
    pub fn pop(u: *Ui, n: i32) void {
        c.goome_ui_pop(u.raw(), n);
    }

    /// A widget you draw yourself. Fills `it` with its pointer state. `flags` are GOOME_ITEM_*, DRAG_X or DRAG_Y alone locks that axis. True if something happened.
    pub fn custom(u: *Ui, id: [*:0]const u8, w: f64, h: f64, flags: c_int, it: *Item) bool {
        return c.goome_ui_custom(u.raw(), id, w, h, flags, it) != 0;
    }

    /// The canvas the ui is drawing on, so your drawing lands in the ui right here, clipped like the widgets.
    pub fn canvas(u: *Ui) ?*Canvas {
        const cv = c.goome_ui_canvas(u.raw());
        if (cv == null) return null;
        return @ptrCast(cv);
    }

    /// Animates a number toward `target` over `ms`. Gives back the current value. `id` keeps the state.
    pub fn anim(u: *Ui, id: [*:0]const u8, target: f64, ms: f64, e: Ease) f64 {
        return c.goome_ui_anim(u.raw(), id, target, ms, @intFromEnum(e));
    }

    /// Same as `anim` but for a color.
    pub fn animColor(u: *Ui, id: [*:0]const u8, target: u32, ms: f64, e: Ease) u32 {
        return c.goome_ui_anim_color(u.raw(), id, target, ms, @intFromEnum(e));
    }

    /// Turns the accessibility tree on or off.
    pub fn a11yOn(u: *Ui, on: bool) void {
        c.goome_ui_a11y(u.raw(), cb(on));
    }

    /// Gives the next `custom` item a role and label for the tree.
    pub fn a11yRole(u: *Ui, role: Role, name: ?[*:0]const u8) void {
        c.goome_ui_a11y_role(u.raw(), @intFromEnum(role), cstr(name));
    }

    /// Gives the next `custom` item a value text for the tree.
    pub fn a11yValue(u: *Ui, value: ?[*:0]const u8) void {
        c.goome_ui_a11y_value(u.raw(), cstr(value));
    }

    /// Fills `buf` with the C tree nodes. Gives back how many nodes the tree has, even when `buf` is too small to hold them all.
    pub fn a11yRaw(u: *Ui, buf: []RawA11yNode) usize {
        const n = c.goome_a11y_tree(u.raw(), buf.ptr, @intCast(buf.len));
        return @intCast(@max(0, n));
    }

    /// Copies the accessibility tree into an `A11yTree`. Free it with `deinit`.
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

    /// `n` doubles kept per id, zero the first time. Null if it cant be made.
    pub fn store(u: *Ui, id: [*:0]const u8, n: usize) ?[]f64 {
        const p = c.goome_ui_store(u.raw(), id, @intCast(n));
        if (p == null) return null;
        return p[0..n];
    }
};

/// Reads a nul terminated buffer as a slice, like what `Ui.input` edits.
pub fn text(buf: []const u8) []const u8 {
    return std.mem.sliceTo(buf, 0);
}

/// Copies a string into a buffer, cut to fit and nul terminated.
pub fn setText(buf: []u8, s: []const u8) void {
    if (buf.len == 0) return;
    const n = @min(s.len, buf.len - 1);
    @memcpy(buf[0..n], s[0..n]);
    buf[n] = 0;
}
