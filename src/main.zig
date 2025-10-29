const std = @import("std");
const builtin = @import("builtin");
const uefi = std.os.uefi;

const utf16 = std.unicode.utf8ToUtf16LeStringLiteral;

const ConIo = struct {
    in: *uefi.protocol.SimpleTextInput,
    out: *uefi.protocol.SimpleTextOutput,
};

const Services = struct {
    boot: *uefi.tables.BootServices,
    runtime: *uefi.tables.RuntimeServices,
};

pub fn main() void {
    const io: ConIo = .{
        .in = uefi.system_table.con_in.?,
        .out = uefi.system_table.con_out.?,
    };

    const services: Services = .{
        .boot = uefi.system_table.boot_services.?,
        .runtime = uefi.system_table.runtime_services,
    };

    _ = io.out.outputString(utf16("hello uefi!\r\n")) catch false;

    _ = services.boot.waitForEvent(&[_]uefi.Event{io.in.wait_for_key}) catch return;
    _ = io.out.outputString(utf16("key was pressed, reading input\r\n")) catch false;

    const input = (io.in.readKeyStroke() catch return).unicode_char;

    var out_string: *[1:0]u16 = @constCast(utf16("_"));
    out_string[0] = input;

    // var out_string: *[2:0]u16 = @constCast(utf16("bb"));
    // out_string[0] = input.unicode_char;

    _ = io.out.outputString(out_string) catch false;

    _ = io.out.outputString(utf16("\r\n")) catch false;

    while (true) {}
}
