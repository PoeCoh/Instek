port: SerialPort,
mirror: Mirror = undefined,

pub fn init(port: []const u8) !Self {
    return Self{
        .port = try SerialPort.init(port, .{
            .baud_rate = 9600,
            .data_bits = 8,
            .parity = .none,
            .stop_bits = 1,
        }),
        .mirror = .{},
    };
}

pub fn deinit(self: *Self) void {
    self.port.deinit();
    self.* = undefined;
}

/// Unlocks physical controls of the device.
pub fn local(self: *Self) !void {
    try self.write("LOCAL");
}

/// Locks physical controls and assumes full control of the device.
pub fn remote(self: *Self) !void {
    try self.write("REMOTE");
}

pub fn independent(self: *Self, ch1: ?Channel, ch2: ?Channel) !void {
    try self.set(.tracking{.independent});
    if (ch1) |c| {
        if (c.voltage) |v| try self.set(.ch1{ .voltage = v });
        if (c.current) |i| try self.set(.ch1{ .current = i });
    }
    if (ch2) |c| {
        if (c.voltage) |v| try self.set(.ch2{ .voltage = v });
        if (c.current) |i| try self.set(.ch2{ .current = i });
    }
}

pub fn series(self: *Self, voltage: ?f32, current: ?f32) !void {
    try self.set(.tracking{.series});
    if (voltage) |v| try self.set(.ch1{ .voltage = v });
    if (current) |i| {
        try self.set(.ch1{ .current = i });
        try self.set(.ch2{ .current = i });
    }
}

pub fn parallel(self: *Self, voltage: ?f32, current: ?f32) !void {
    try self.set(.tracking{.parallel});
    if (voltage) |v| try self.set(.ch1{ .voltage = v });
    if (current) |i| try self.set(.ch1{ .current = i });
}

pub fn power(self: *Self, on: bool) !void {
    try self.set(.output{ .on = on });
}

pub fn enableBeep(self: *Self, on: bool) !void {
    try self.set(.beep{ .on = on });
}

const std = @import("std");
const SerialPort = @import("SerialPort");
const Self = @This();
const eql = std.mem.eql;

fn write(self: *Self, data: []const u8) !void {
    self.port.write(data);
    self.port.write("\n");
}

fn getStatus(self: *Self) !Status {
    var buffer: [8]u8 = undefined;
    self.write("STATUS?");
    _ = try self.port.read(&buffer);
    const status = Status.parse(buffer);
    self.tracking = status.tracking;
    self.output = status.output;
    self.beep = status.beep;
    return status;
}

const Status = struct {
    ch1: Mode,
    ch2: Mode,
    tracking: Tracking,
    beep: bool,
    output: bool,
    baud: Baud,

    pub fn parse(bytes: [8]u8) Status {
        return .{
            .ch1 = parseMode(bytes[0]),
            .ch2 = parseMode(bytes[1]),
            .tracking = parseTracking(bytes[2..3]),
            .beep = eql(u8, bytes[4], "1"),
            .output = eql(u8, bytes[5], "1"),
            .baud = @enumFromInt(bytes[6..7]),
        };
    }

    fn parseTracking(bytes: [2]u8) Tracking {
        if (eql(u8, bytes, "01")) return .independent;
        if (eql(u8, bytes, "10")) return .parallel;
        if (eql(u8, bytes, "11")) return .series;
    }

    fn parseMode(bytes: [1]u8) Mode {
        return if (eql(u8, bytes, "0")) .continuous_current else .continuous_voltage;
    }
};

const Baud = enum(u4) {
    B115200 = 0,
    B57600 = 1,
    B9600 = 10,
};

const Ch = enum(u3) { one = 1, two = 2 };

const Mode = enum(u2) { continuous_current = 0, continuous_voltage = 1 };

const Property = enum { voltage, current };

const Errors = error{
    ProgramMnemonicTooLong,
    InvalidCharacter,
    MissingParameter,
    DataOutOfRange,
    CommandNotAllowed,
    UndefinedHeader,
};

const Tracking = enum(u3) {
    independent = 0,
    series = 1,
    parallel = 2,
};

const Mirror = struct {
    tracking: Tracking = .independent,
    ch1: Channel = .{},
    ch2: Channel = .{},
    beep: bool = false,
    output: bool = false,
};

const Channel = struct {
    voltage: ?f32 = null,
    current: ?f32 = null,
};

const Set = union(enum) {
    tracking: Tracking,
    ch1: Channel,
    ch2: Channel,
    beep: bool,
    output: bool,
};

fn setVoltage(self: *Self, channel: Ch, voltage: f32) !void {
    if (self.isSet(channel, .voltage, voltage)) return;
    try self.write("VOUT{d}:{d}", .{ @intFromEnum(channel), voltage });
}

fn setCurrent(self: *Self, channel: Ch, current: f32) !void {
    if (self.isSet(channel, .current, current)) return;
    try self.write("IOUT{d}:{d}", .{ @intFromEnum(channel), current });
    self.mirror.ch1.current = current;
}

fn set(self: *Self, s: Set) !void {
    switch (s) {
        .tracking => |t| {
            if (self.mirror.tracking == t) return;
            try self.write("TRACK{d}", .{@intFromEnum(t)});
            self.mirror.tracking = t;
        },
        .ch1 => |c| {
            if (c.voltage) |v| {
                try self.setVoltage(.one, v);
                self.mirror.ch1.voltage = v;
            }
            if (c.current) |i| {
                try self.setCurrent(.one, i);
                self.mirror.ch1.current = i;
            }
        },
        .ch2 => |c| {
            if (c.voltage) |v| {
                try self.setVoltage(.two, v);
                self.mirror.ch2.voltage = v;
            }
            if (c.current) |i| {
                try self.setCurrent(.two, i);
                self.mirror.ch2.current = i;
            }
        },
        .beep => |b| {
            if (self.mirror.beep == b) return;
            try self.write("BEEP{d}", .{@intFromBool(b)});
            self.mirror.beep = b;
        },
        .output => |o| {
            if (self.mirror.output == o) return;
            try self.write("OUTPUT{d}", .{@intFromBool(o)});
            self.mirror.output = o;
        },
    }
}

fn isSet(self: *Self, ch: Ch, property: Property, value: f32) bool {
    const channel = switch (ch) {
        .one => self.mirror.ch1,
        .two => self.mirror.ch2,
    };
    return value == switch (property) {
        .voltage => channel.voltage,
        .current => channel.current,
    } orelse -1;
}
