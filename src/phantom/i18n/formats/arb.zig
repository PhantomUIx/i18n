const std = @import("std");

pub fn TypeDef(comptime value: []const u8) type {
    const buflen = value.len * 3;
    var buf: [buflen]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);

    var scanner = std.json.Scanner.initCompleteInput(fba.allocator(), value);
    defer scanner.deinit();

    var count: usize = 0;
    var i: usize = 0;
    while (true) {
        const token = scanner.next() catch |e| @compileError("Failed to parse ARB file: " ++ @errorName(e));
        if (token == .end_of_document) break;

        if (token == .string) {
            const is_field = (i % 2) == 0;
            if (is_field and token.string[0] != '@') count += 1;

            i += 1;
        }
    }

    var fields: [count]std.builtin.Type.StructField = undefined;

    scanner.deinit();
    scanner = std.json.Scanner.initCompleteInput(fba.allocator(), value);

    i = 0;
    while (true) {
        const token = scanner.next() catch |e| @compileError("Failed to parse ARB file: " ++ @errorName(e));
        if (token == .end_of_document) break;

        if (token == .string) {
            const is_field = (i % 2) == 0;
            const field_index = if (is_field) i / 2 else i - 1;

            if (is_field and token.string[0] != '@') {
                fields[field_index] = .{
                    .name = token.string,
                    .type = []const u8,
                    .default_value = null,
                    .is_comptime = false,
                    .alignment = field_index,
                };
            }

            i += 1;
        }
    }

    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}

pub inline fn load(alloc: std.mem.Allocator, comptime T: type, value: []const u8) !T {
    return (try std.json.parseFromSlice(T, alloc, value, .{
        .allocate = .alloc_always,
    })).value;
}

pub fn comptimeLoad(comptime value: []const u8) TypeDef(value) {
    comptime {
        const buflen = value.len * 3;
        var buf: [buflen]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        return load(fba.allocator(), TypeDef(value), value) catch |e| @compileError("Failed to parse ARB file: " ++ @errorName(e));
    }
}
