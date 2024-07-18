const std = @import("std");
const GPD = @import("GPD.zig");

test "independent" {
    const gpd = try GPD.independent("COM1", .{
        .ch1 = .{ .voltage = 12, .current = 1 },
        .ch2 = .{ .voltage = 12, .current = 1 },
    });
    defer gpd.deinit();

    try gpd.on();
    _ = try gpd.read(.one, .voltage);
}

test "series" {
    const gpd = try GPD.series("COM1", .{
        .tracked = .{ .voltage = 12, .current = 1 },
    });
    defer gpd.deinit();

    try gpd.on();
    _ = try gpd.read(.tracked, .voltage);
}

test "parallel" {
    const gpd = try GPD.parallel("COM1", .{
        .tracked = .{ .voltage = 12, .current = 1 },
    });
    defer gpd.deinit();

    try gpd.on();
    _ = try gpd.read(.tracked, .voltage);
}
