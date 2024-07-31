/// Serial port that connects to the X303S.
port: SerialPort,

/// Model of the X303S.
model: Model = undefined,

/// Serial number of the X303S.
serial: []const u8 = undefined,

/// Firmware version of the X303S.
version: []const u8 = undefined,

/// Create a new X303S instance.
/// Power supply will be turned off, placed in independent mode, and zeroed.
pub fn init(port: []const u8) !X303S {
    var gpd = X303S{
        .port = try SerialPort.init(port, .{
            .baud_rate = 115200,
            .data_bits = .CS8,
            .parity = .none,
            .stop_bits = .one,
            .flow_control = .none,
            .timeout = 100,
        }),
    };
    errdefer gpd.deinit();
    try gpd.remote();
    try gpd.power(.off);
    try gpd.independent(
        .{ .voltage = 0, .current = 0 },
        .{ .voltage = 0, .current = 0 },
    );
    if (gpd.model == .gpd_3303s) return gpd;
    try gpd.channel3(.{ .voltage = 0, .current = 0 });
    try gpd.channel4(.{ .voltage = 0, .current = 0 });
    return gpd;
}

/// Deinitializes the X303S.
pub fn deinit(self: *X303S) void {
    self.port.deinit();
    self.* = undefined;
}

/// Enables or disables the output.
pub fn power(self: *X303S, state: State) !void {
    try self.write("OUT{d}", .{@intFromEnum(state)});
}

/// Locks physical controls and assumes full control of the device.
pub fn remote(self: *X303S) !void {
    try self.write("REMOTE", .{});
}

/// Unlocks physical controls of the device.
pub fn local(self: *X303S) !void {
    try self.write("LOCAL", .{});
}

/// Sets the tracking mode to independent. Channels are not connected.
pub fn independent(self: *X303S, ch1: ?Settings, ch2: ?Settings) !void {
    try self.setTracking(.independent);
    if (ch1) |s| try self.setChannel(.ch1, s);
    if (ch2) |s| try self.setChannel(.ch2, s);
}

/// Sets the tracking mode to series. Channels 1 and 2 are connected in series.
pub fn series(self: *X303S, settings: Settings) !void {
    try self.setTracking(.series);
    if (settings.voltage) |v| try self.set(.ch1, .voltage, v / 2);
    if (settings.current) |c| try self.set(.ch1, .current, c);
    try self.set(.ch2, .current, 3);
}

/// Sets the tracking mode to parallel. Channels 1 and 2 are connected in parallel.
pub fn parallel(self: *X303S, settings: Settings) !void {
    try self.setTracking(.parallel);
    if (settings.voltage) |v| try self.set(.ch1, .voltage, v);
    if (settings.current) |c| try self.set(.ch1, .current, c / 2);
}

/// Sets the channel 3 to the given settings.
pub fn channel3(self: *X303S, settings: Settings) !void {
    if (self.modeel == .gpd_3303s) return error.NotAvailable;
    try self.setChannel(.ch3, settings);
}

/// Sets the channel 4 to the given settings.
pub fn channel4(self: *X303S, settings: Settings) !void {
    if (self.model == .gpd_3303s) return error.NotAvailable;
    try self.setChannel(.ch4, settings);
}

/// Enables or disables the beep.
pub fn beep(self: *X303S, state: State) !void {
    try self.write("BEEP{d}", .{@intFromEnum(state)});
}

const std = @import("std");
const SerialPort = @import("SerialPort");
const X303S = @This();

fn setTracking(self: *X303S, tracking: Tracking) !void {
    try self.write("TRACK{d}", .{@intFromEnum(tracking)});
}

fn setChannel(self: *X303S, c: Ch, s: Settings) !void {
    if (s.voltage) |v| try self.set(c, .voltage, v);
    if (s.current) |v| try self.set(c, .current, v);
}

fn set(self: *X303S, c: Ch, p: Property, v: f32) !void {
    try validateNumber(p, v);
    var buffer = std.mem.zeroes([53]u8);
    const float = try std.fmt.formatFloat(&buffer, v, .{
        .mode = .decimal,
        .precision = 3,
    });
    try self.write(
        "{s}OUT{d}:{d}",
        .{ if (p == .voltage) "V" else "I", @intFromEnum(c), float },
    );
}

fn validateNumber(p: Property, v: f32) !void {
    if (0 > v) return error.CannotBeNegative;
    switch (p) {
        .voltage => if (32 < v) return error.VoltageTooHigh,
        .current => if (3.2 < v) return error.CurrentTooHigh,
    }
}

fn write(self: *X303S, fmt: []const u8, args: anytype) !void {
    var buffer = std.mem.zeroes([14]u8);
    const bytes = try std.fmt.bufPrint(&buffer, fmt, args);
    self.port.write(bytes);
    self.port.write("\n");
}

const State = enum(u2) {
    off = 0,
    on = 1,
};

const Property = enum {
    voltage,
    current,
};

const Model = enum(u4) {
    gpd_3303s = 3,
    gpd_4303s = 4,
};

const Tracking = enum(u2) {
    independent = 0,
    series = 1,
    parallel = 2,
};

const Ch = enum(u3) {
    one = 1,
    two = 2,
    three = 3,
    four = 4,
};

const Settings = struct {
    voltage: ?f32 = null,
    current: ?f32 = null,
};
