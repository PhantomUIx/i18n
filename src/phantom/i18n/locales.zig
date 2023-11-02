const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

fn fieldIndex(comptime T: type, name: []const u8) ?u8 {
    inline for (std.meta.fields(T), 0..) |field, i| {
        if (std.mem.eql(u8, field.name, name))
            return i;
    }
    return null;
}

pub fn Locales(comptime LocaleCode: type, comptime T: type) type {
    const LocalesMap = std.AutoHashMap(LocaleCode, T);

    const LocalesStatic = if (LocaleCode == []const u8) void else if (std.meta.activeTag(@typeInfo(LocaleCode)) == .Enum) @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = blk: {
                const e = @typeInfo(LocaleCode).Enum;
                var fields: [e.fields.len]std.builtin.Type.StructField = undefined;
                for (e.fields, &fields, 0..) |s, *d, i| {
                    d.* = .{
                        .name = s.name,
                        .type = ?T,
                        .default_value = null,
                        .is_comptime = false,
                        .alignment = i,
                    };
                }
                break :blk &fields;
            },
            .decls = &.{},
            .is_tuple = false,
        },
    }) else @compileError("Incompatible type for locale code: " ++ @typeName(LocaleCode));

    const LocalesData = union(enum) {
        static: LocalesStatic,
        map: LocalesMap,
    };

    return struct {
        const Self = @This();
        const Tag = std.meta.FieldEnum(T);

        locales: LocalesData,
        fallback: ?LocaleCode = null,

        pub fn getLocaleCode(self: Self) error{UnknownLocale}!LocaleCode {
            const langs = [_]?[]const u8{ if (std.os.getenv("LANG")) |l| blk: {
                var iter = std.mem.splitAny(u8, l, ".");
                break :blk iter.first();
            } else null, if (self.fallback) |f| std.enums.tagName(LocaleCode, f) else null, if (LocaleCode != []const u8) @typeInfo(LocaleCode).Enum.fields[0].name else null };

            if (LocaleCode == []const u8) {
                for (langs) |lang| {
                    if (lang) |val| return val;
                }
                return error.UnknownLocale;
            }

            for (langs) |lang| {
                if (lang) |val| {
                    inline for (@typeInfo(LocaleCode).Enum.fields) |f| {
                        if (std.mem.eql(u8, f.name, val)) return @enumFromInt(f.value);
                    }
                }
            }

            return error.UnknownLocale;
        }

        fn getLocaleStatic(self: Self, localeCode: LocaleCode) ?T {
            assert(self.locales == .static);
            assert(LocalesStatic != void);

            const tag = if (LocalesStatic == []const u8) localeCode else std.enums.tagName(LocaleCode, localeCode) orelse return null;

            inline for (@typeInfo(LocaleCode).Enum.fields) |f| {
                if (std.mem.eql(u8, f.name, tag)) return @field(self.locales.static, f.name);
            }

            return null;
        }

        pub fn getLocaleFor(self: Self, locale: LocaleCode) error{NotMapped}!T {
            const value = switch (self.locales) {
                .static => self.getLocaleStatic(locale),
                .map => |m| m.get(locale),
            };
            return value orelse error.NotMapped;
        }

        pub fn getLocale(self: Self) error{ NotMapped, UnknownLocale }!T {
            var l = self.getLocaleFor(try self.getLocaleCode());
            if (l != error.NotMapped) return l;

            if (self.fallback) |f| {
                l = self.getLocaleFor(f);
                if (l != error.NotMapped) return l;
            }

            return if (LocaleCode != []const u8) self.getLocaleFor(@enumFromInt(@typeInfo(LocaleCode).Enum.fields[0].value)) else error.NotMapped;
        }

        pub fn get(self: Self, tag: Tag) error{ UnknownLocaleTag, NotMapped, UnknownLocale }![]const u8 {
            const locale = try self.getLocale();

            const tagName = std.enums.tagName(Tag, tag) orelse return error.UnknownLocaleTag;

            inline for (@typeInfo(Tag).Enum.fields) |f| {
                if (std.mem.eql(u8, f.name, tagName)) return @field(locale, f.name);
            }
            return error.UnknownLocaleTag;
        }
    };
}
