const std = @import("std");

const cf = @cImport({
    @cInclude("CoreFoundation/CoreFoundation.h");
    @cInclude("CoreGraphics/CoreGraphics.h");
});

pub const Key = struct {
    code: u64,
    flags: u64,
};

pub const Binding = union(enum) {
    const Self = @This();
    chord: Chord,
    command: Command,

    pub fn isEqual(self: Self, key: Key) bool {
        return switch (self) {
            inline else => |b| b.isEqual(key),
        };
    }

    pub fn apply(self: Self) void {
        switch (self) {
            inline else => |*s| s.apply(),
        }
    }
};

pub const Chord = struct {
    const Self = @This();
    in: Key,
    out: []const Key,

    pub fn isEqual(self: Self, key: Key) bool {
        return key.code == self.in.code and key.flags == self.in.flags;
    }

    pub fn apply(self: Self) void {
        for (self.out) |item| {
            const event = cf.CGEventCreateKeyboardEvent(null, @as(u16, @intCast(item.code)), true);
            cf.CGEventSetFlags(event, @as(u64, @intCast(item.flags)));
            cf.CGEventPost(cf.kCGHIDEventTap, event);
            cf.CFRelease(event);
        }
    }
};

pub const Command = struct {
    const Self = @This();
    in: Key,
    command: []const []const u8,

    pub fn isEqual(self: Self, key: Key) bool {
        return key.code == self.in.code and key.flags == self.in.flags;
    }

    pub fn apply(self: Self) void {
        const allocator = std.heap.page_allocator;

        var child = std.process.Child.init(self.command, allocator);
        child.stdin_behavior = .Inherit;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        child.spawn() catch |err| {
            std.debug.print("Failed to spawn child: {}\n", .{err});
            return;
        };

        // IN CASE WE WANT TO WAIT FOR THE END OF EXEC
        // Handle wait error
        // const term = child.wait() catch |err| {
        //     std.debug.print("Failed to wait on child: {}\n", .{err});
        //     return;
        // };
        // std.debug.print(" --> {} <--\n", .{term});
    }
};
