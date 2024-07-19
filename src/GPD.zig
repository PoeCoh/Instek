/// Configure GPD in independent mode. Ommitted settings will be zeroed.
pub fn independent(port: []const u8, config: common.IndependentConfig) !Independent {
    var sp = try getPort(port);
    var gpd = Independent{ .port = &sp };
    try common.zero(&sp);
    try common.tracking(&sp, .independent);
    try gpd.configure(config);
    return gpd;
}

pub fn series(port: []const u8, config: common.SeriesConfig) !Series {
    var sp = try getPort(port);
    var gpd = Series{ .port = &sp };
    try common.zero(&sp);
    try common.tracking(&sp, .series);
    try gpd.configure(config);
    return gpd;
}

pub fn parallel(port: []const u8, config: common.SeriesConfig) !Parallel {
    var sp = try getPort(port);
    var gpd = Parallel{ .port = &sp };
    try common.zero(&sp);
    try common.tracking(&sp, .parallel);
    try gpd.configure(config);
    return gpd;
}

const std = @import("std");
const SerialPort = @import("SerialPort");
const Independent = @import("Independent.zig");
const Series = @import("Series.zig");
const Parallel = @import("Parallel.zig");
const common = @import("common.zig");
const Self = @This();

fn getPort(port: []const u8) !SerialPort {
    return SerialPort.init(port, .{
        .baud_rate = 9600,
        .word_size = .CS8,
        .parity = .none,
        .stop_bits = .one,
    });
}
