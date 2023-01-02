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

pub const WebParameter = struct { key: []const u8, value: []const u8 };

pub const MimeType = struct { type: []const u8, subtype: []const u8, parameter: WebParameter };

pub const WebResponse = struct {
    version: []const u8,
    code: u16,
    type: MimeType,
    content: []const u8,
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

    var response = WebResponse{
        .version = headers.version[0 .. headers.version.len - 1],
        .code = 200,
        .type = MimeType{ .type = "text", .subtype = "plain", .parameter = WebParameter{
            .key = "",
            .value = "",
        } },
        .content = "kono dio da",
    };

    try sendResponse(connection, response);
}

fn receiveHeaders(allocator: mem.Allocator, connection: StreamServer.Connection) !*WebHeader {
    var client_reader = connection.stream.reader();

    var line = try client_reader.readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));

    var first_line = mem.split(u8, line, " ");
    var headers = try allocator.create(WebHeader);
    var hashmap = std.StringHashMap([]const u8).init(allocator);

    var a = first_line.next().?;
    a = a[0..a.len];
    var b = first_line.next().?;
    b = b[0..b.len];
    var c = first_line.next().?;
    c = c[0..c.len];
    headers.* = WebHeader{ .method = a, .resource = b, .version = c, .optionals_list = hashmap };

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

fn sendResponse(connection: StreamServer.Connection, response: WebResponse) !void {
    var client_writer = connection.stream.writer();

    const message = switch (response.code) {
        200 => "OK",
        404 => "Not Found",
        403 => "Forbidden",
        else => "Unknown",
    };

    try client_writer.print("{s} {} {s}\r\n", .{ response.version, response.code, message });
    try client_writer.print("Content-Type: {s}/{s}\r\n", .{ response.type.type, response.type.subtype });
    try client_writer.print("Content-Length: {}\r\n\r\n", .{response.content.len});
    try client_writer.print("{s}", .{response.content});
}
