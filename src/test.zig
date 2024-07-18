const std = @import("std");

test "sanity" {
    const buffer = "1";
    const result = std.mem.eql(u8, buffer, "1");
    try std.testing.expect(result);

}

test "parse" {
    const buffer = "1";
    const result = try std.fmt.parseInt(u8, buffer, 10);
    try std.testing.expectEqual(result, 1);
}