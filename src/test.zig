const std = @import("std");
const X303S = @import("X303S.zig");

test "basic" {
    var gpd = try X303S.init("COM1");
    defer gpd.deinit();
    try gpd.independent(
        .{ .voltage = 12, .current = 3 },
        .{},
    );
    try gpd.series(.{ .voltage = 40, .current = 3 });
    try gpd.parallel(.{ .voltage = 12, .current = 6 });
    try gpd.beep(.on);
    try gpd.power(.on);
    try gpd.independent(.{ .voltage = 3 }, .{ .current = 1 });
}
