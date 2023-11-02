pub fn Import(comptime phantom: type) type {
    return struct {
        pub const i18n = @import("phantom/i18n.zig").Import(phantom);
    };
}
