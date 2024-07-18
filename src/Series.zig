port: SerialPort,

/// Configures GPD in series mode. Ommitted settings will not be changed.
pub fn configure(self: *Self, config: Config) !void {
    try common.remote(self.port);
    try common.tracking(self.port, .series);
    try common.setCurrent(self.port, .two, 3);
    if (config.tracked) |c| {
        try common.setVoltage(self.port, 1, c.voltage / 2);
        try common.setCurrent(self.port, 1, c.current);
    }
    if (config.ch3) |ch3| {
        try common.setVoltage(self.port, 3, ch3.voltage);
        try common.setCurrent(self.port, 3, ch3.current);
    }
    if (config.ch4) |ch4| {
        try common.setVoltage(self.port, .four, ch4.voltage);
        try common.setCurrent(self.port, .four, ch4.current);
    }
}

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
const Config = common.SeriesConfig;

const Property = enum {
    voltage,
    current,
};

const Channel = enum(u3) {
    tracked = 1,
    three = 3,
    four = 4,
};
