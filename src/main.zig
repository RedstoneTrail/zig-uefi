const std = @import("std");
const builtin = @import("builtin");
const uefi = std.os.uefi;

const utf16 = std.unicode.utf8ToUtf16LeStringLiteral;

const letters: [2 ^ 16]u16 = blk: {
    var letters_generated: [2 ^ 16]u16 = undefined;
    for (0..letters_generated.len - 1) |idx| {
        letters_generated[idx] = idx;
    }
    break :blk letters_generated;
};

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

    const blank_out = "you put a \"_\"";
    var out_string: *[blank_out.len:0]u16 = @constCast(utf16(blank_out));

    out_string[out_string.len - 3] = letters[input];

    if (out_string[out_string.len - 3] == letters[input]) {
        _ = io.out.outputString(utf16("memory was written properly\r\n")) catch false;
    } else {
        _ = io.out.outputString(utf16("memory was not written properly\r\n")) catch false;
    }

    if (input == 0) {
        _ = io.out.outputString(utf16("input is 0\r\n")) catch false;
    }

    if (input == 'a') {
        _ = io.out.outputString(utf16("input is a\r\n")) catch false;
    }

    _ = io.out.outputString(out_string) catch false;

    _ = io.out.outputString(utf16("\r\n")) catch false;

    while (true) {}
}
