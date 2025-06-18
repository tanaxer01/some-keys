const std = @import("std");
const hotkeys = @import("hotkeys.zig");

const cf = @cImport({
    @cInclude("CoreFoundation/CoreFoundation.h");
    @cInclude("CoreGraphics/CoreGraphics.h");
});

const Key = hotkeys.Key;
const Binding = hotkeys.Binding;
const Chord = hotkeys.Chord;
const Command = hotkeys.Command;

fn eventTapCallback(_: cf.CGEventTapProxy, kind: cf.CGEventType, event: cf.CGEventRef, ref: ?*anyopaque) callconv(.c) cf.CGEventRef {
    const arr = @as(*std.ArrayList(Binding), @ptrCast(@alignCast(ref.?)));
    const currKey = Key{
        .code = @intCast(cf.CGEventGetIntegerValueField(event, cf.kCGKeyboardEventKeycode)),
        .flags = @intCast(cf.CGEventGetFlags(event)),
    };

    std.debug.print("INPUT {} \n", .{currKey});
    switch (kind) {
        cf.kCGEventKeyDown, cf.kCGEventFlagsChanged => {
            for (arr.items) |b| {
                if (b.isEqual(currKey)) {
                    b.apply();
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
    var bindings = std.ArrayList(Binding).init(alloc);
    defer bindings.deinit();

    try bindings.append(.{ .command = Command{
        .in = .{ .code = 1, .flags = 0x100 },
        .command = &[_][]const u8{ "touch", "file.txt" },
    } });

    try bindings.append(.{ .chord = Chord{
        .in = .{ .code = 0, .flags = 0x100 },
        .out = &[_]Key{
            .{ .code = 0, .flags = 0x100 },
            .{ .code = 0, .flags = 0x100 },
            .{ .code = 0, .flags = 0x100 },
        },
    } });

    const eventMask: cf.CGEventMask = cf.CGEventMaskBit(cf.kCGEventKeyDown) | cf.CGEventMaskBit(cf.kCGEventFlagsChanged);
    const eventTap = cf.CGEventTapCreate(cf.kCGSessionEventTap, cf.kCGHeadInsertEventTap, cf.kCGEventTapOptionDefault, eventMask, eventTapCallback, &bindings);
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
