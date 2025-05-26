const std = @import("std");

pub const hotkey = struct {
    key: i64,
    flags: i64,
};

pub const binding = struct {
    in: hotkey,
    out: []const hotkey,
};

test "create a cord" {
    const key = [_]hotkey{.{ .key = 1, .flags = 1 }};
    try std.testing.expect(key.len == 1);

    const keys = [_]hotkey{
        .{ .key = 1, .flags = 1 },
    };
    try std.testing.expect(keys.len == 1);

    const aa = binding{
        .in = .{ .key = 1, .flags = 1 },
        .out = &.{
            .{ .key = 0, .flags = 0 },
            .{ .key = 1, .flags = 0 },
            .{ .key = 2, .flags = 0 },
            .{ .key = 3, .flags = 0 },
        },
    };
    try std.testing.expect(aa.out.len == 3);
}
