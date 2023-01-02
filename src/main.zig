const std = @import("std");
const mem = std.mem;
const net = std.net;
const StreamServer = std.net.StreamServer;
const Address = std.net.Address;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

pub const WebHeader = struct {
    method: []const u8,
    resource: []const u8,
    version: []const u8,
    optionals_list: std.StringHashMap([]const u8),
};

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

    var headers = try receiveHeaders(allocator, connection);
    defer allocator.destroy(headers);
    var i = headers.*.optionals_list.iterator();
    while (i.next()) |entry| {
        std.debug.print("{s} : {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    var client_writer = connection.stream.writer();
    try client_writer.print("{s}\r\n{s}\r\n{s}\r\n\r\n{s}\r\n\r\n", .{ "HTTP/1.1 200 OK", "Content-Type: text/plain", "Content-Length: 10", "dank memes" });
}

fn receiveHeaders(allocator: mem.Allocator, connection: StreamServer.Connection) !*WebHeader {
    var client_reader = connection.stream.reader();

    var line = try client_reader.readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));

    var first_line = mem.split(u8, line, " ");
    var headers = try allocator.create(WebHeader);
    var hashmap = std.StringHashMap([]const u8).init(allocator);
    headers.* = WebHeader{ .method = first_line.next().?, .resource = first_line.next().?, .version = first_line.next().?, .optionals_list = hashmap };

    std.debug.print("**HEADER**\nMethod: {s}\nResource: {s}\nProtocol: {s}\n", .{ headers.method, headers.resource, headers.version });

    while (true) {
        line = try client_reader.readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
        if (line.len == 1 and mem.eql(u8, line, "\r")) break;

        var this_line = mem.split(u8, line, ":");

        const key = this_line.next().?;
        var value = this_line.rest();
        if (value[0] == ' ') value = value[1..value.len];

        try headers.optionals_list.put(key, value);
    }

    return headers;
}
