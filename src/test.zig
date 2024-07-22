const std = @import("std");

test "this stuff" {
    var buffer: [1024:0]u8 = undefined;
    _ = try std.fmt.bufPrint(&buffer, "12.1{d}V", .{42});
    const v_index = std.mem.indexOf(u8, &buffer, "V") orelse 0;
    const voltage = buffer[0..v_index];
    std.debug.print("{s}\n", .{voltage});}