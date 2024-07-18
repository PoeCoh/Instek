port: SerialPort,

/// Configures GPD in independent mode. Ommitted settings will not be changed.
pub fn configure(self: *Self, config: Config) !void {
    try common.remote(self.port);
    try common.tracking(self.port, .independent);
    if (config.ch1) |ch1| {
        try common.setVoltage(self.port, 1, ch1.voltage);
        try common.setCurrent(self.port, 1, ch1.current);
    }
    if (config.ch2) |ch2| {
        try common.setVoltage(self.port, 2, ch2.voltage);
        try common.setCurrent(self.port, 2, ch2.current);
    }
    if (config.ch3) |ch3| {
        try common.setVoltage(self.port, 3, ch3.voltage);
        try common.setCurrent(self.port, 3, ch3.current);
    }
    if (config.ch4) |ch4| {
        try common.setVoltage(self.port, 4, ch4.voltage);
        try common.setCurrent(self.port, 4, ch4.current);
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
const Config = common.IndependentConfig;

const Property = enum {
    voltage,
    current,
};

const Channel = enum(u3) {
    one = 1,
    two = 2,
    three = 3,
    four = 4,
};
