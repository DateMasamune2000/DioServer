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
        try handleClient(my_allocator, connection);
    }
}

fn handleClient(allocator: mem.Allocator, connection: StreamServer.Connection) !void {
    defer connection.stream.close();

    var client_writer = connection.stream.writer();
    var client_reader = connection.stream.reader();

    var line = try client_reader.readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));

    var first_line = mem.split(u8, line, " ");
    const method = first_line.next().?;
    const resource = first_line.next().?;
    const protocol = first_line.next().?;

    var headers = std.StringHashMap([]const u8).init(allocator);

    std.debug.print("**HEADER**\nMethod: {s}\nResource: {s}\nProtocol: {s}\n", .{ method, resource, protocol });

    while (true) {
        line = try client_reader.readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));

        if (line.len == 1 and mem.eql(u8, line, "\r")) break;

        var this_line = mem.split(u8, line, ":");

        const key = this_line.next().?;
        var value = this_line.rest();

        if (value[0] == ' ') value = value[1..value.len];

        try headers.put(key, value);
    }

    var i = headers.iterator();
    while (i.next()) |entry| {
        std.debug.print("{s} : {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    try client_writer.print("{s}\r\n{s}\r\n{s}\r\n\r\n{s}\r\n\r\n", .{ "HTTP/1.1 200 OK", "Content-Type: text/plain", "Content-Length: 10", "dank memes" });
}
