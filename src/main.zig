const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const sdl = c.sdl;
const m = @import("math.zig").math;
const App = @import("App.zig");
const globals = @import("globals.zig");
const fatal = @import("utils.zig").fatal;

var app: App = undefined;
var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
var is_debug: bool = false;

pub fn main() !u8 {
    app_err.reset();
    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status: u8 = @truncate(@as(c_uint, @bitCast(sdl.SDL_RunApp(empty_argv.len, @ptrCast(&empty_argv), sdlMainC, null))));
    return app_err.load() orelse status;
}

fn sdlMainC(argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c_int {
    return sdl.SDL_EnterAppMainCallbacks(argc, @ptrCast(argv), sdlAppInitC, sdlAppIterateC, sdlAppEventC, sdlAppQuitC);
}

fn sdlAppInit(appstate: ?*?*anyopaque, argv: [][*:0]u8) !sdl.SDL_AppResult {
    _ = appstate;
    _ = argv;

    const allocator, const dbg = gpa: {
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    is_debug = dbg;
    App.init(allocator);

    // if (builtin.mode != .Debug and builtin.os.tag == .macos) {
    //     _ = std.posix.setenv("MTL_DEBUG_LAYER", "0", true);
    // }

    return sdl.SDL_APP_CONTINUE;
}

fn sdlAppIterate(appstate: ?*anyopaque) !sdl.SDL_AppResult {
    _ = appstate;
    return App.frame();
}

fn sdlAppEvent(appstate: ?*anyopaque, event: *sdl.SDL_Event) !sdl.SDL_AppResult {
    return globals.event_loop.process(appstate, event);
}

fn sdlAppQuit(appstate: ?*anyopaque, result: anyerror!sdl.SDL_AppResult) void {
    _ = appstate;
    _ = result catch {};

    const asserts = sdl.SDL_GetAssertionReport();
    var assert = asserts;
    while (assert != null) : (assert = assert[0].next) {
        std.log.debug(
            "{s}, {s} ({s}:{}), triggered {} times, always ignore: {}.",
            .{ assert[0].condition, assert[0].function, assert[0].filename, assert[0].linenum, assert[0].trigger_count, assert[0].always_ignore },
        );
    }

    globals.deinit();

    if (is_debug) {
        std.debug.assert(debug_allocator.deinit() == .ok);
    }
}

fn sdlAppInitC(appstate: ?*?*anyopaque, argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) sdl.SDL_AppResult {
    return sdlAppInit(appstate.?, @ptrCast(argv.?[0..@intCast(argc)])) catch |err| app_err.store(err);
}

fn sdlAppIterateC(appstate: ?*anyopaque) callconv(.c) sdl.SDL_AppResult {
    return sdlAppIterate(appstate) catch |err| app_err.store(err);
}

fn sdlAppEventC(appstate: ?*anyopaque, event: ?*sdl.SDL_Event) callconv(.c) sdl.SDL_AppResult {
    return sdlAppEvent(appstate, event.?) catch |err| app_err.store(err);
}

fn sdlAppQuitC(appstate: ?*anyopaque, result: sdl.SDL_AppResult) callconv(.c) void {
    sdlAppQuit(appstate, app_err.load() orelse result);
}

var app_err: ErrorStore = .{};

const ErrorStore = struct {
    const status_not_stored = 0;
    const status_storing = 1;
    const status_stored = 2;

    status: sdl.SDL_AtomicInt = .{},
    err: anyerror = undefined,
    trace_index: usize = undefined,
    trace_addrs: [32]usize = undefined,

    fn reset(es: *ErrorStore) void {
        _ = sdl.SDL_SetAtomicInt(&es.status, status_not_stored);
    }

    fn store(es: *ErrorStore, err: anyerror) sdl.SDL_AppResult {
        if (sdl.SDL_CompareAndSwapAtomicInt(&es.status, status_not_stored, status_storing)) {
            es.err = err;
            if (@errorReturnTrace()) |src_trace| {
                es.trace_index = src_trace.index;
                const len = @min(es.trace_addrs.len, src_trace.instruction_addresses.len);
                @memcpy(es.trace_addrs[0..len], src_trace.instruction_addresses[0..len]);
            }
            _ = sdl.SDL_SetAtomicInt(&es.status, status_stored);
        }
        return sdl.SDL_APP_FAILURE;
    }

    fn load(es: *ErrorStore) ?anyerror {
        if (sdl.SDL_GetAtomicInt(&es.status) != status_stored) return null;
        if (@errorReturnTrace()) |dst_trace| {
            dst_trace.index = es.trace_index;
            const len = @min(dst_trace.instruction_addresses.len, es.trace_addrs.len);
            @memcpy(dst_trace.instruction_addresses[0..len], es.trace_addrs[0..len]);
        }
        return es.err;
    }
};
