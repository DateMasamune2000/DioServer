const std = @import("std");
const net = std.net;
const StreamServer = std.net.StreamServer;
const Address = std.net.Address;

pub fn main() !void {
    var my_server = StreamServer.init(.{ .reuse_address = true });
    defer my_server.close();

    const address = try Address.resolveIp("127.0.0.1", 8088);
    try my_server.listen(address);

    while (true) {
        const connection = try my_server.accept();
        try connection.stream.writer().print("hello, world", .{});
        connection.stream.close();
    }
}
