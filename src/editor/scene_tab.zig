const std = @import("std");
const Allocator = std.mem.Allocator;
const Set = @import("../set.zig").Set;
const globals = @import("../globals.zig");
const oom = @import("../utils.zig").oom;

pub const Manager = struct {
    tabs: Set(Tab) = .empty,
    active: usize,
    init: bool,
    next: usize,

    pub const max_tabs = 16;
    pub const empty: Manager = .{
        .tabs = .empty,
        .active = 0,
        .init = false,
        .next = 0,
    };

    pub fn initWithCapacity() Manager {
        var self: Manager = .empty;
        self.tabs.ensureUnused(globals.allocator, max_tabs) catch oom();
        return self;
    }

    pub fn deinit(self: *Manager) void {
        self.tabs.deinit(globals.allocator);
    }

    pub fn add(self: *Manager) void {
        if (self.tabs.count() >= max_tabs) {
            return;
        }

        var tab: Tab = .empty;
        const unsaved = "unsaved (*)";
        @memcpy(tab.name[0..unsaved.len], unsaved);
        self.tabs.addAssume(tab);
    }

    pub fn clean(self: *Manager) void {
        _ = self; // autofix

        // Remove closed tabs
        // var i: usize = 0;
        // while (i < tab_count) {
        //     if (!tab_open[i]) {
        //         var j: usize = i;
        //         while (j + 1 < tab_count) : (j += 1) {
        //             tab_names[j] = tab_names[j + 1];
        //             tab_open[j] = tab_open[j + 1];
        //         }
        //         tab_count -= 1;
        //         if (active_tab >= tab_count and tab_count > 0) {
        //             active_tab = tab_count - 1;
        //         }
        //     } else {
        //         i += 1;
        //     }
        // }
    }
};

pub const Tab = struct {
    name: [32:0]u8,
    open: bool,

    pub const empty: Tab = .{
        .name = @splat(0),
        .open = true,
    };
};
