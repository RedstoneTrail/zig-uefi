const std = @import("std");
const builtin = @import("builtin");
const uefi = std.os.uefi;

const utf16 = std.unicode.utf8ToUtf16LeStringLiteral;

fn clamp(T: type, val: T, min: T, max: T) T {
    return @min(max, @max(min, val));
}

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
    geometry: Geometry,
};

const Geometry = struct {
    row: usize,
    col: usize,
    max_row: usize,
    max_col: usize,
};

const Services = struct {
    boot: *uefi.tables.BootServices,
    runtime: *uefi.tables.RuntimeServices,
};

pub fn main() void {
    var io: ConIo = .{
        .in = uefi.system_table.con_in.?,
        .out = uefi.system_table.con_out.?,
        .geometry = .{
            .row = 0,
            .col = 0,
            .max_col = 0,
            .max_row = 0,
        },
    };
    io.out.enableCursor(true) catch return;
    io.out.setMode(0) catch return;
    {
        const geo = io.out.queryMode(0) catch return;
        io.geometry.max_col = geo.columns;
        io.geometry.max_row = geo.rows;
    }
    io.out.clearScreen() catch return;

    const services: Services = .{
        .boot = uefi.system_table.boot_services.?,
        .runtime = uefi.system_table.runtime_services,
    };

    // _ = io.out.outputString(utf16("this is an example uefi application\r\n<BS> clears screen currently\r\n")) catch false;

    while (true) {
        _ = services.boot.waitForEvent(&[_]uefi.Event{io.in.wait_for_key}) catch return;

        const input = (io.in.readKeyStroke() catch return).unicode_char;

        if (io.geometry.col == io.geometry.max_col - 1) {
            _ = io.out.outputString(utf16("\r\n")) catch false;
            io.geometry.col = 0;
            io.geometry.row += 1;
        }

        if (io.geometry.row == io.geometry.max_row) {
            io.out.clearScreen() catch return;
            io.geometry.col = 0;
            io.geometry.row = 0;
        }

        if (input == '\r') {
            io.geometry.col = 0;
            io.geometry.row += 1;
            _ = io.out.outputString(utf16("\r\n")) catch false;
        } else if (input == 0) {
            // _ = io.out.reset(true) catch return;
            // _ = io.out.outputString(utf16("this is an example uefi application\r\n<BS> clears screen currently\r\n")) catch false;
            // _ = io.out.outputString(utf16("\x00")) catch false;
            // _ = io.out.setCursorPosition(@min(io.mode.columns, @max(0, io.out.mode.cursor_column - 1)), @min(io.mode.rows, @max(0, io.out.mode.cursor_row))) catch unreachable;
            if (io.geometry.row == 0 and io.geometry.col == 0) {
                continue;
            }
            if (io.geometry.col == 0) {
                io.geometry.row -= 1;
                // io.geometry.col = io.geometry.max_col - 1;
            } else {
                io.geometry.col -= 1;
                io.out.setCursorPosition(io.geometry.col, io.geometry.row) catch return;
                _ = io.out.outputString(utf16(" ")) catch false;
            }
            io.out.setCursorPosition(io.geometry.col, io.geometry.row) catch return;
        } else {
            const blank_out = "_";
            var out_string: [blank_out.len:0]u16 = undefined;

            _ = std.unicode.utf8ToUtf16Le(&out_string, blank_out) catch return;

            out_string[out_string.len] = 0;
            out_string[out_string.len - 1] = input;

            io.geometry.col += 1;

            _ = io.out.outputString(&out_string) catch return;
        }
    }

    // while (true) {}
}
