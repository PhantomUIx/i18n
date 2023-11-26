const std = @import("std");

pub const formats = @import("i18n/formats.zig");
pub const Format = std.meta.DeclEnum(formats);

pub usingnamespace @import("i18n/locales.zig");
