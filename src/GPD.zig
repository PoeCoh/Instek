model: Model = undefined,
private: Private,

pub fn init(allocator: Allocator, port: []const u8) !Self {
    var sp = try SerialPort.init(port, .{
        .baud_rate = 115200,
        .word_size = .CS8,
        .parity = .none,
        .stop_bits = .one,
    });
    var gpd = Self{ .private = Private{
        .port = &sp,
    } };
    gpd.reset();
    return gpd;
}

pub fn deinit(self: *Self) void {
    self.private.port.deinit();
}

pub fn configure(self: *Self, config: Config) !void {}

const std = @import("std");
const SerialPort = @import("SerialPort");
const Self = @This();
const Allocator = std.mem.Allocator;

const Private = struct {
    port: SerialPort = undefined,
    tracking: Tracking = .independent,
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

const Config = union(enum) {
    independent: Independent,
    series: Series,
    parallel: Series,
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

const Info = struct {
    model: Model,
    serial: []const u8,
    version: []const u8,
    baud_rate: BaudRate,
};

fn reset(self: *Self) !void {
    try self.setVoltage(1, 0);
    try self.setCurrent(1, 0);
    try self.setVoltage(2, 0);
    try self.setCurrent(2, 0);
    if (self.model == .gpd_3303s) return;
    try self.setVoltage(3, 0);
    try self.setCurrent(3, 0);
    try self.setVoltage(4, 0);
    try self.setCurrent(4, 0);
}

fn setTracking(self: *Self, track: Tracking) !void {
    try self.write("TRACK{d}", .{@intFromEnum(track)});
}

fn setVoltage(self: *Self, channel: u8, voltage: f32) !void {
    try self.write("VSET{d}:{d}", .{ channel, voltage });
    // minimum response time is 10ms
    std.time.sleep(10 * std.time.ns_per_ms);
}

fn setCurrent(self: *Self, channel: u8, current: f32) !void {
    try self.write("ISET{d}:{d}", .{ channel, current });
    // minimum response time is 10ms
    std.time.sleep(10 * std.time.ns_per_ms);
}

fn write(self: *Self, fmt: []const u8, args: anytype) !void {
    var buffer: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try std.fmt.format(fbs.writer(), fmt, args);
    const str = fbs.getWritten();
    self.private.port.write(str);
    self.private.port.write("\n");
}

fn read(self: *Self, buffer: []u8) ![]const u8 {
    try self.private.port.read(buffer[0..]);
    return buffer[0..];
}

fn testPort(port: []const u8, baud_rate: u23) !Info {
    var sp = try SerialPort.init(port, .{
        .baud_rate = baud_rate,
        .word_size = .CS8,
        .parity = .none,
        .stop_bits = .one,
    });
    defer sp.deinit();
    try sp.write("\n");
    try sp.flush(.both);
    try sp.write("*IDN?\n");
    var buffer: [1024]u8 = undefined;
    try sp.read(buffer[0..]);
    // response is formatted as "GW INSTEK,GPD-4303S,SN:12334567,V2.0"
    // we need to split the string into 4 parts by the comma
    const good = std.mem.containsAtLeast(u8, buffer[0..], 1, "GW INSTEK");
    if (!good) return error.InvalidResponse;
    var iterator = std.mem.splitSequence(u8, buffer[0..], ",");
    _ = iterator.next() orelse return error.InvalidResponse; // manufacturer
    const model = iterator.next() orelse return error.InvalidResponse;
    const sn = iterator.next() orelse return error.InvalidResponse;
    const version = iterator.next() orelse return error.InvalidResponse;
    var fmt_buffer = [_]u8{0} ** 10;
    const baud = try std.fmt.bufPrint(&fmt_buffer, "B{d}", .{baud_rate});
    
    return .{
        .model = try std.meta.stringToEnum(Model, model),
        .serial = sn[3..],
        .version = version[1..],
        .baud_rate = try std.meta.stringToEnum(BaudRate, baud),
    };
}
