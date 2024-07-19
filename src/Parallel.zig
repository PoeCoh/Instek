port: SerialPort,


pub fn on(self: *Self) !void {
    try common.on(self.port);
}

pub fn off(self: *Self) !void {
    try common.off(self.port);
}

pub fn read(self: *Self, channel: Channel, property: Property) !f32 {
    return switch (property) {
        .voltage => common.getVoltage(self.port, @intFromEnum(channel)),
        .current => common.getCurrent(self.port, @intFromEnum(channel)),
    };
}

pub fn deinit(self: *Self) void {
    try self.off();
    self.port.deinit();
}

const std = @import("std");
const SerialPort = @import("SerialPort");
const common = @import("common.zig");
const Self = @This();
const Config = common.ParallelConfig;

const Property = enum {
    voltage,
    current,
};

const Channel = enum(u3) {
    tracked = 1,
    three = 3,
    four = 4,
};
