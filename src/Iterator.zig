buffer: [1024]u8 = undefined,
fba: std.heap.FixedBufferAllocator,

pub fn init() Self {
    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    return .{ .fba = &fba, .buffer = buffer };
}

pub fn next(self: *Self) ?GPD {
    const gpd = GPD.init();
}

const std = @import("std");
const Self = @This();
const GPD = @import("GPDX303S.zig");