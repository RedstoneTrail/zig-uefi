const std = @import("std");
const builtin = @import("builtin");
const uefi = std.os.uefi;

const utf16 = std.unicode.utf8ToUtf16LeStringLiteral;

fn clamp(T: type, val: T, min: T, max: T) T {
    return @min(max, @max(min, val));
}

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

const uefiColours = uefi.protocol.SimpleTextOutput.Attribute;

fn clear(io: *ConIo) void {
    io.out.setAttribute(.{
        .background = uefiColours.BackgroundColor.lightgray,
        .foreground = uefiColours.ForegroundColor.blue,
    }) catch unreachable;

    io.out.clearScreen() catch unreachable;

    io.out.setAttribute(.{
        .background = uefiColours.BackgroundColor.black,
        .foreground = uefiColours.ForegroundColor.white,
    }) catch unreachable;

    for (0..io.geometry.max_col * io.geometry.max_row) |_| {
        _ = io.out.outputString(utf16(" ")) catch unreachable;
    }

    io.geometry.col = 0;
    io.geometry.row = 0;

    io.out.setCursorPosition(io.geometry.col, io.geometry.row) catch unreachable;
}

pub fn main() void {
    // put conio stuff here
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

    // show cursor so you know where you are
    io.out.enableCursor(true) catch unreachable;

    // set mode for certain
    io.out.setMode(0) catch unreachable;

    // get output geometry
    {
        const geo = io.out.queryMode(0) catch unreachable;
        io.geometry.max_col = geo.columns;
        io.geometry.max_row = geo.rows;
    }

    clear(&io);

    if (io.geometry.max_col == 80 and io.geometry.max_row == 25) {
        _ = io.out.outputString(utf16("size is that of standard mode 0 (80x25)\r\r\n")) catch false;
    }

    _ = io.out.outputString(utf16("welcome to the text editor app\r\n\nyou can write across the whole black space on your screen\r\nreaching the right edge wraps\r\ngoing past the bottom clears\r\n\npress F1 to clear the screen\r\npress F2 to quit\r\n\npress any key to begin")) catch false;

    // put service tables here
    const services: Services = .{
        .boot = uefi.system_table.boot_services.?,
        .runtime = uefi.system_table.runtime_services,
    };

    _ = services.boot.waitForEvent(&[_]uefi.Event{io.in.wait_for_key}) catch unreachable;
    _ = io.in.readKeyStroke() catch unreachable;
    clear(&io);

    while (true) {
        // wait until you press a key
        _ = services.boot.waitForEvent(&[_]uefi.Event{io.in.wait_for_key}) catch unreachable;

        // read it
        const input = io.in.readKeyStroke() catch unreachable;

        if (io.geometry.col == io.geometry.max_col) {
            // we are at the end of the line, wrap to next line
            io.geometry.col = 0;
            io.geometry.row += 1;
            continue;
        } else if (io.geometry.row == io.geometry.max_row) {
            // we are at the bottom and have filled the screen, reset state
            clear(&io);
            continue;
        } else if (input.unicode_char == '\r') {
            // pressed enter, go to next line
            io.geometry.col = 0;
            io.geometry.row += 1;
            _ = io.out.outputString(utf16("\r\n")) catch false;
            continue;
        } else if (input.unicode_char == 8) {
            // probably pressed backspace
            if (io.geometry.col == 0 and io.geometry.row == 0) {
                // we are at top left, do nothing
                io.out.setCursorPosition(io.geometry.col, io.geometry.row) catch unreachable;
                continue;
            }
            if (io.geometry.col == 0 and io.geometry.row != 0) {
                // at the left, but not on the top row, go back up
                io.geometry.row -= 1;
                // must be -2 to avoid immediately moving to next line in earlier checks
                io.geometry.col = io.geometry.max_col - 2;
            } else {
                io.geometry.col -= 1;
                io.out.setCursorPosition(io.geometry.col, io.geometry.row) catch unreachable;
                _ = io.out.outputString(utf16(" ")) catch false;
            }
            io.out.setCursorPosition(io.geometry.col, io.geometry.row) catch unreachable;
        } else if (input.scan_code == 0x0b) {
            // F1 clears screen
            clear(&io);
            io.geometry.col = 0;
            io.geometry.row = 0;
            continue;
        } else if (input.scan_code == 0x0c) {
            // F2 quits
            _ = io.out.outputString(utf16("F2 was pressed, quitting")) catch false;
            std.Thread.sleep(std.time.ns_per_s);
            return;
        } else {
            const blank_out = "_";
            var out_string: [blank_out.len:0]u16 = undefined;

            _ = std.unicode.utf8ToUtf16Le(&out_string, blank_out) catch unreachable;

            out_string[out_string.len] = 0;
            out_string[out_string.len - 1] = input.unicode_char;

            io.geometry.col += 1;

            _ = io.out.outputString(&out_string) catch unreachable;
        }
    }
}
