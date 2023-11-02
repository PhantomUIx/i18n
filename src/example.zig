const std = @import("std");
const i18n = @import("phantom.i18n").import(struct {}).i18n;

pub fn main() !void {
    const Locale = i18n.formats.arb.TypeDef(@embedFile("example.arb"));
    const locales = i18n.Locales(enum {
        en_US,
        ja_JP,
    }, Locale){
        .locales = .{
            .static = .{
                .en_US = i18n.formats.arb.load(std.heap.page_allocator, Locale, @embedFile("example.arb")) catch @panic("OOM"),
                .ja_JP = null,
            },
        },
    };

    std.debug.print("{s}\n", .{try locales.get(.helloWorld)});
}
