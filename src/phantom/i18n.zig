const std = @import("std");

pub fn import(comptime _: type) type {
    return struct {
        const i18n = @This();

        pub const formats = @import("i18n/formats.zig");
        pub const Format = std.meta.DeclEnum(formats);

        pub usingnamespace @import("i18n/locales.zig");
    };
}
