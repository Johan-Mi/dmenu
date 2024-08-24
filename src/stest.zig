const std = @import("std");

var match = false;
var flags = [_]bool{false} ** ('z' - 'a');
var time_to_compare: i128 = undefined;

fn flag(letter: u8) bool {
    return flags[letter - 'a'];
}

fn matches_filters(path: []const u8, name: []const u8) !bool {
    if (!flag('a') and std.mem.startsWith(u8, name, ".")) return false; // hidden file

    const cwd = std.fs.cwd();
    const st = cwd.statFile(path) catch return false;

    if (flag('x')) { // executable
        var buffer = std.BoundedArray(u8, std.fs.max_path_bytes){};
        try buffer.writer().print("{s}\x00", .{path});
        if (std.c.access(@ptrCast(buffer.slice()), std.posix.X_OK) != 0) return false;
    }

    return ((!flag('b') or st.kind == .block_device) //
    and (!flag('c') or st.kind == .character_device) //
    and (!flag('d') or st.kind == .directory) //
    and (!flag('f') or st.kind == .file) //
    and (!flag('g') or st.mode & std.posix.S.ISGID != 0) // set-group-id flag
    and (!flag('h') or cwd.readLink(path, &.{}) != error.NotLink) // symbolic link
    and (!flag('n') or st.mtime > time_to_compare) // newer than file
    and (!flag('o') or st.mtime < time_to_compare) // older than file
    and (!flag('p') or st.kind == .named_pipe) //
    and (!flag('r') or if (cwd.access(path, .{ .mode = .read_only })) true else |_| false) //
    and (!flag('s') or st.size != 0) // not empty
    and (!flag('u') or st.mode & std.posix.S.ISUID != 0) // set-user-id flag
    and (!flag('w') or if (cwd.access(path, .{ .mode = .write_only })) true else |_| false));
}

fn check(path: []const u8, name: []const u8) !void {
    if (matches_filters(path, name) catch false != flag('v')) {
        if (flag('q'))
            std.process.exit(0);
        match = true;
        try std.io.getStdOut().writer().print("{s}\n", .{name});
    }
}

fn usage(me: []const u8) !noreturn {
    try std.io.getStdErr().writer().print(
        "usage: {s} [-abcdefghlpqrsuvwx] [-n file] [-o file] [file...]\n",
        .{me},
    );
    std.process.exit(2);
}

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var args = std.os.argv;

    if (args.len == 0) return error.MissingArgv0;
    const argv0 = args[0];

    args.ptr += 1;
    args.len -= 1;
    while (args.len != 0 and args[0][0] == '-' and args[0][1] != '\x00') : (args = args[1..]) {
        var argc_: u8 = undefined;
        var argv_: [*][*:0]u8 = undefined;
        if (args[0][1] == '-' and args[0][2] == '\x00') {
            args = args[1..];
            break;
        }

        args[0] += 1;
        argv_ = args.ptr;
        while (args[0][0] != '\x00') : (args[0] += 1) {
            if (argv_ != args.ptr) break;
            argc_ = args[0][0];
            switch (argc_) {
                'n', // newer than file
                'o', // older than file
                => {
                    const file_ = if (args[0][1] != '\x00') args[0][1..] else if (2 <= args.len) blk: {
                        args = args[1..];
                        break :blk args[0];
                    } else try usage(std.mem.span(argv0));
                    const file = std.mem.span(file_);
                    if (std.fs.cwd().statFile(file)) |stat| {
                        time_to_compare = stat.mtime;
                        flags[argc_ - 'a'] = true;
                    } else |err| try std.io.getStdErr().writer().print("{s}: {}\n", .{ file, err });

                    break;
                },
                else => {
                    _ = std.mem.indexOfScalar(u8, "abcdefghlpqrsuvwx", argc_) orelse
                        try usage(std.mem.span(argv0));
                    flags[argc_ - 'a'] = true;
                },
            }
        }
    }

    if (args.len == 0) {
        var stdin = std.io.getStdIn();
        var reader = std.io.bufferedReader(stdin.reader());
        var line = std.ArrayList(u8).init(allocator);
        defer line.deinit();

        while (reader.reader().streamUntilDelimiter(line.writer(), '\n', null)) {
            defer line.clearRetainingCapacity();
            try check(line.items, line.items);
        } else |err| switch (err) {
            error.EndOfStream => if (line.items.len != 0)
                try check(line.items, line.items),
            else => return err,
        }
    } else for (args) |arg_| {
        const arg = std.mem.span(arg_);
        if (!flag('l')) {
            try check(arg, arg);
        } else if (std.fs.cwd().openDir(arg, .{ .iterate = true })) |dir_| {
            var dir = dir_;
            defer dir.close();
            var iter = dir.iterate();
            while (iter.next() catch null) |entry| {
                var path = std.BoundedArray(u8, std.fs.max_path_bytes){};
                if (path.writer().print("{s}/{s}", .{ arg, entry.name }))
                    try check(path.slice(), entry.name)
                else |_| {}
            }
        } else |_| {}
    }

    return @intFromBool(!match);
}
