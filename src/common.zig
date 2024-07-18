const std = @import("std");
const eql = std.mem.eql;
const SerialPort = @import("SerialPort");

pub const IndependentConfig = struct {
    ch1: ?Settings = null,
    ch2: ?Settings = null,
    ch3: ?Settings = null,
    ch4: ?Settings = null,
};

const SeriesConfig = struct {
    tracked: ?Settings = null,
    ch3: ?Settings = null,
    ch4: ?Settings = null,
};

const ParallelConfig = struct {
    tracked: ?Settings = null,
    ch3: ?Settings = null,
    ch4: ?Settings = null,
};

pub const Settings = struct {
    voltage: ?f32 = null,
    current: ?f32 = null,
};

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

const Mode = enum(u2) { continuous_current = 0, continuous_voltage = 1 };

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

fn write(port: SerialPort, fmt: []const u8, args: []const u8) !void {
    var buffer: [15]u8 = undefined;
    _ = try std.fmt.bufPrint(buffer[0..], fmt, args) catch unreachable;
    _ = port.write(buffer[0..]);
    _ = port.write("\n");
}

fn read(port: SerialPort) ![]u8 {
    var buffer: [25]u8 = undefined;
    _ = try port.read(buffer[0..]);
    return buffer[0..];
}

// fn getStatus(self: *Self) !Status {
//     var buffer: [8]u8 = undefined;
//     try self.write("STATUS?", .{});
//     _ = try self.port.read(&buffer);
//     const status = Status.parse(buffer);
//     self.mirror.tracking = status.tracking;
//     self.mirror.output = status.output;
//     self.mirror.beep = status.beep;
//     return status;
// }

pub fn on(p: *SerialPort) !void {
    try write(p, "OUT1", .{});
}

pub fn off(p: *SerialPort) !void {
    try write(p, "OUT0", .{});
}

pub fn remote(p: *SerialPort) !void {
    try write(p, "REMOTE", .{});
}

pub fn setVoltage(p: *SerialPort, c: u3, v: ?f32) !void {
    const volts = v orelse return;
    if (0 > volts or volts > 30) return error.VoltageOutOfRange;
    try write(p, "VSET{d}:{d}", .{ c, volts });
}

pub fn setCurrent(p: *SerialPort, c: u3, i: ?f32) !void {
    const current = i orelse return;
    if (0 > current or current > 3) return error.CurrentOutOfRange;
    try write(p, "ISET{d}:{d}", .{ c, current });
}

pub fn tracking(p: *SerialPort, track: Tracking) !void {
    try write(p, "TRACK{d}", .{@intFromEnum(track)});
}

pub fn getVoltage(p: *SerialPort, c: u3) !f32 {
    try write(p, "VSET{d}?", .{c});
    return std.fmt.parseFloat(f32, try read(p));
}

pub fn getCurrent(p: *SerialPort, c: u3) !f32 {
    try write(p, "ISET{d}?", .{c});
    return std.fmt.parseFloat(f32, try read(p));
}

pub fn zero(p: *SerialPort) !void {
    try off(p);
    try setVoltage(p, 1, 0);
    try setCurrent(p, 1, 0);
    try setVoltage(p, 2, 0);
    try setCurrent(p, 2, 0);
    try setVoltage(p, 3, 0);
    try setCurrent(p, 3, 0);
    try setVoltage(p, 4, 0);
    try setCurrent(p, 4, 0);
}