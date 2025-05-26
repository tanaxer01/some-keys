const std = @import("std");
const hotkeys = @import("hotkeys.zig");

const cf = @cImport({
    @cInclude("CoreFoundation/CoreFoundation.h");
    @cInclude("CoreGraphics/CoreGraphics.h");
});

const hotkey = hotkeys.hotkey;
const binding = hotkeys.binding;

fn eventTapCallback(_: cf.CGEventTapProxy, kind: cf.CGEventType, event: cf.CGEventRef, ref: ?*anyopaque) callconv(.c) cf.CGEventRef {
    const arr = @as(*std.ArrayList(binding), @ptrCast(@alignCast(ref.?)));

    const flags = cf.CGEventGetFlags(event);
    const keyCode = cf.CGEventGetIntegerValueField(event, cf.kCGKeyboardEventKeycode);
    std.debug.print("INPUT {d} {x}\n", .{ keyCode, flags });
    switch (kind) {
        cf.kCGEventKeyDown, cf.kCGEventFlagsChanged => {
            for (arr.items) |b| {
                if (b.in.key == keyCode and b.in.flags == flags) {
                    for (b.out) |item| {
                        const key = cf.CGEventCreateKeyboardEvent(null, @as(u16, @intCast(item.key)), true);
                        cf.CGEventSetFlags(key, @as(u64, @intCast(item.flags)));
                        cf.CGEventPost(cf.kCGHIDEventTap, key);
                        cf.CFRelease(key);
                    }

                    return null;
                }
            }

            return event;
        },
        else => {},
    }

    return event;
}

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("some_keys_lib");

const CFErrors = error{
    FailedToCreateEventTap,
    FailedToCreateLoopSource,
};

pub fn main() !void {
    std.debug.print("Attempting to use CoreFoundation functions...\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();
    var hks = std.ArrayList(binding).init(alloc);
    defer hks.deinit();

    try hks.append(.{
        .in = .{ .key = 0, .flags = 0x80140 },
        .out = &.{
            .{ .key = 33, .flags = 0x100 },
            .{ .key = 0, .flags = 0x100 },
        },
    });

    const eventMask: cf.CGEventMask = cf.CGEventMaskBit(cf.kCGEventKeyDown) | cf.CGEventMaskBit(cf.kCGEventFlagsChanged);
    const eventTap = cf.CGEventTapCreate(cf.kCGSessionEventTap, cf.kCGHeadInsertEventTap, cf.kCGEventTapOptionDefault, eventMask, eventTapCallback, &hks);
    if (eventTap == null) {
        std.debug.print("Failed to create eventTap!\n", .{});
        return CFErrors.FailedToCreateEventTap;
    }

    const runLoopSource = cf.CFMachPortCreateRunLoopSource(cf.kCFAllocatorDefault, eventTap, 0);
    if (runLoopSource == null) {
        std.debug.print("Failed to create loop source!\n", .{});
        cf.CFRelease(eventTap);

        return CFErrors.FailedToCreateLoopSource;
    }

    cf.CFRunLoopAddSource(cf.CFRunLoopGetCurrent(), runLoopSource, cf.kCFRunLoopCommonModes);
    cf.CFRunLoopRun();

    std.debug.print("Event tap is running (Press Ctrl-C to stop)....\n", .{});

    cf.CFRunLoopRemoveSource(cf.CFRunLoopGetCurrent(), runLoopSource, cf.kCFRunLoopCommonModes);
    cf.CFRelease(runLoopSource);
    cf.CFRelease(eventTap);
}
