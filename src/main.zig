const std = @import("std");
const mem = std.mem;
const net = std.net;
const StreamServer = std.net.StreamServer;
const Address = std.net.Address;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

pub fn main() !void {
    var my_server = StreamServer.init(.{ .reuse_address = true });
    var gpa = GeneralPurposeAllocator(.{}){};
    var my_allocator = gpa.allocator();
    defer my_server.close();

    const address = try Address.resolveIp("127.0.0.1", 8088);
    try my_server.listen(address);

    while (true) {
        const connection = try my_server.accept();
        defer connection.stream.close();
        try handleClient(my_allocator, connection);
    }
}

fn handleClient(allocator: mem.Allocator, connection: StreamServer.Connection) !void {
    var client_writer = connection.stream.writer();
    var client_reader = connection.stream.reader();

    var a = try client_reader.readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
    defer (allocator.free(a));

    std.debug.print("{s}\n", .{a});

    try client_writer.print("[SERVER_MESSAGE] {s}\r\n", .{a});
}
