private: Private,

pub fn init(port_name: []const u8) void {
    const info = try tryPort(port_name) orelse error.CouldNotIdentify;
    var gpd = GPD{ .private = .{
        .baud_rate = info.baud_rate,
        .tracking = .independent,
        .model = if (info.identity.model[4] == '3') .gpd_3303s else .gpd_4303s,
        .port = try SerialPort.init(port_name, .{
            .baud_rate = info.baud_rate,
            .data_bits = 8,
            .parity = .None,
            .stop_bits = 1,
        }),
    } };
    try gpd.setTracking(.independent);
    try gpd.setVoltage(1, 0);
    try gpd.setCurrent(1, 0);
    try gpd.setVoltage(2, 0);
    try gpd.setCurrent(2, 0);
    if (gpd.private.model == .gpd_3303s) return gpd;
    try gpd.setVoltage(3, 0);
    try gpd.setCurrent(3, 0);
    try gpd.setVoltage(4, 0);
    try gpd.setCurrent(4, 0);
    return gpd;
}

pub fn configure(self: *GPD, config: Config) !void {
    return switch (config) {
        .independent => |c| self.configIndependent(c),
        .series => |c| self.configSeries(c),
        .parallel => |c| self.configParallel(c),
    };
}

pub fn on(self: *GPD) !void {
    try self.write("OUT1");
}

pub fn off(self: *GPD) !void {
    try self.write("OUT0");
}

pub fn local(self: *GPD) !void {
    try self.write("LOCAL");
}

pub fn remote(self: *GPD) !void {
    try self.write("REMOTE");
}

pub fn read(self: *GPD, channel: Ch, property: Property) !f32 {
    const function = if (property == .voltage) getVoltage else getCurrent;
    if (channel == .three or channel == .four) return function(self, @intFromEnum(channel));
    switch (self.private.tracking) {
        .independent => {
            if (channel == .tracked) return error.InvalidChannel;
            return function(self, @intFromEnum(channel));
        },
        .series => {
            if (channel != .tracked) return error.InvalidChannel;
            switch (property) {
                .voltage => {
                    const channel_1 = try self.getVoltage(1);
                    const channel_2 = try self.getVoltage(2);
                    return channel_1 + channel_2;
                },
                .current => return self.getCurrent(1),
            }
        },
        .parallel => {
            if (channel != .tracked) return error.InvalidChannel;
            switch (property) {
                .voltage => return self.getVoltage(1),
                .current => return self.getCurrent(1) * 2,
            }
        },
    }
}

const std = @import("std");
const GPD = @This();
const SerialPort = @import("SerialPort");

const Private = struct {
    baud_rate: BaudRate = undefined,
    tracking: Tracking = undefined,
    model: Model = undefined,
    port: SerialPort = undefined,
};

const Model = enum {
    gpd_3303s,
    gpd_4303s,
};

const Tracking = enum(u2) {
    independent = 0,
    series = 1,
    parallel = 2,
};

const BaudRate = enum(u2) {
    B115200 = 0,
    B57600 = 1,
    B9600 = 2,
};

const Property = enum {
    voltage,
    current,
};

const Config = union(enum) {
    independent: Independent,
    series: Series,
    parallel: Parallel,
};

const Independent = struct {
    ch1: ?Channel = null,
    ch2: ?Channel = null,
    ch3: ?Channel = null,
    ch4: ?Channel = null,
};

const Series = struct {
    tracked: ?Channel = null,
    ch3: ?Channel = null,
    ch4: ?Channel = null,
};

const Parallel = struct {
    tracked: ?Channel = null,
    ch3: ?Channel = null,
    ch4: ?Channel = null,
};

const Channel = struct {
    voltage: ?f32 = null,
    current: ?f32 = null,
};

const Identity = struct {
    manufacturer: []const u8,
    model: []const u8,
    serial: []const u8,
    version: std.SemanticVersion,
};

const Info = struct {
    identity: Identity = null,
    baud_rate: u32 = null,
};

const Ch = enum(u3) {
    tracked = 1,
    one = 1,
    two = 2,
    three = 3,
    four = 4,
};

fn configIndependent(self: *GPD, independent: Independent) !void {
    try self.setTracking(.independent);
    if (independent.ch1) |c| {
        try self.setVoltage(1, c.voltage);
        try self.setCurrent(1, c.current);
    }
    if (independent.ch2) |c| {
        try self.setVoltage(2, c.voltage);
        try self.setCurrent(2, c.current);
    }
    if (self.private.model == .gpd_3303s) return;
    try self.configOther(independent);
}

fn configSeries(self: *GPD, series: Series) !void {
    try self.setTracking(.series);
    if (series.tracked) |c| {
        try self.setVoltage(1, c.voltage / 2);
        try self.setCurrent(1, c.current);
        try self.setCurrent(2, 3);
    }
    if (self.private.model == .gpd_3303s) return;
    try self.configOther(series);
}

fn configParallel(self: *GPD, parallel: Parallel) !void {
    try self.setTracking(.parallel);
    if (parallel.tracked) |c| {
        try self.setVoltage(1, c.voltage);
        try self.setCurrent(1, c.current / 2);
    }
    if (self.private.model == .gpd_3303s) return;
    try self.configOther(parallel);
}

fn configOther(self: *GPD, config: anytype) !void {
    if (config.ch3) |c| {
        try self.setVoltage(3, c.voltage);
        try self.setCurrent(3, c.current);
    }
    if (config.ch4) |c| {
        try self.setVoltage(4, c.voltage);
        try self.setCurrent(4, c.current);
    }
}

fn write(self: *GPD, fmt: []const u8, args: anytype) !void {
    var buffer: [14:0]u8 = undefined;
    const string = try std.fmt.bufPrint(&buffer, fmt, args);
    _ = try self.private.port.write(string);
    _ = try self.private.port.write("\n");
}

fn setVoltage(self: *GPD, channel: u23, voltage: ?f32) !void {
    const v = voltage orelse return;
    try self.write("VSET{d}:{d}", .{ channel, v });
}

fn setCurrent(self: *GPD, channel: u23, current: ?f32) !void {
    const c = current orelse return;
    try self.write("ISET{d}:{d}", .{ channel, c });
}

fn setTracking(self: *GPD, tracking: Tracking) !void {
    try self.write("TRACK{d}", .{@intFromEnum(tracking)});
    self.private.tracking = tracking;
}

fn getVoltage(self: *GPD, channel: u32) !f32 {
    if (self.private.model == .gpd_3303s and channel > 2)
        return error.InvalidChannel;
    try self.write("VOUT{d}", .{channel});
    var buffer: [1024:0]u8 = undefined;
    _ = try self.private.port.read(&buffer);
    const v_index = std.mem.indexOf(u8, &buffer, "V") orelse 0;
    return std.fmt.parseFloat(f32, buffer[0..v_index]);
}

fn getCurrent(self: *GPD, channel: u32) !f32 {
    if (self.private.model == .gpd_3303s and channel > 2)
        return error.InvalidChannel;
    try self.write("IOUT{d}", .{channel});
    var buffer: [1024:0]u8 = undefined;
    _ = try self.private.port.read(&buffer);
    const i_index = std.mem.indexOf(u8, &buffer, "A") orelse 0;
    return std.fmt.parseFloat(f32, buffer[0..i_index]);
}

fn tryPort(port_name: []const u8) !?Info {
    const baud_rates = [_]u32{ 115200, 57600, 9600 };
    for (baud_rates) |baud_rate| {
        const identity = try tryIndentify(port_name, baud_rate) orelse continue;
        return .{
            .identity = identity,
            .baud_rate = baud_rate,
        };
    }
}

fn tryIndentify(port_name: []const u8, baud_rate: u23) !?Identity {
    var sp = try SerialPort.init(port_name, .{
        .baud_rate = baud_rate,
        .data_bits = 8,
        .parity = .None,
        .stop_bits = 1,
    });
    defer sp.deinit();
    return identify(&sp);
}

fn identify(p: *SerialPort) !?Identity {
    var in_buffer: [1024:0]u8 = undefined;
    // clear out anything that might be sitting in the device's buffer
    p.write("\n");
    std.time.sleep(std.time.ns_per_ms * 100);
    p.flush();

    p.write("*IDN?\n");
    std.time.sleep(std.time.ns_per_ms * 100);
    _ = try p.read(&in_buffer);
    var iterator = std.mem.splitSequence(u8, in_buffer, ",");
    const manufacturer = iterator.next() orelse return null;
    const model = iterator.next() orelse return null;
    const serial = iterator.next() orelse return null;
    const version = iterator.next() orelse return null;
    var format_buffer = std.mem.zeroes([10]u8);
    const full_version = try std.fmt.bufPrint(&format_buffer, "{s}.0", .{version[1..]});
    return .{
        .manufacturer = manufacturer,
        .model = model,
        .serial = serial[3..],
        .version = try std.SemanticVersion.parse(full_version),
    };
}
