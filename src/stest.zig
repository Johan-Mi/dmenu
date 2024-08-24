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
    and (!flag('w') or if (cwd.access(path, .{ .mode = .write_only })) true else |_| false) //
    and (!flag('x') or st.mode & (std.posix.S.IXUSR | std.posix.S.IXGRP | std.posix.S.IXOTH) != 0)); // executable
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

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    const me = args.next() orelse return error.MissingArgv0;

    var finished_flags = false;
    var any_positionals = false;
    while (args.next()) |arg_| {
        var arg = arg_;
        if (finished_flags) {
            any_positionals = true;
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
        } else if (std.mem.startsWith(u8, arg, "-") and 2 <= arg.len and !std.mem.eql(u8, arg, "--")) {
            while (true) {
                arg = arg[1..];
                const c = arg[0];
                switch (c) {
                    'n', // newer than file
                    'o', // older than file
                    => {
                        const file = if (2 <= arg.len) arg[1..] else args.next() orelse try usage(me);
                        if (std.fs.cwd().statFile(file)) |stat| {
                            time_to_compare = stat.mtime;
                            flags[c - 'a'] = true;
                        } else |err| try std.io.getStdErr().writer().print("{s}: {}\n", .{ file, err });
                        finished_flags = true;
                    },
                    else => {
                        _ = std.mem.indexOfScalar(u8, "abcdefghlpqrsuvwx", c) orelse
                            try usage(me);
                        flags[c - 'a'] = true;
                    },
                }
            }
        } else {
            finished_flags = true;
        }
    }

    if (!any_positionals) {
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
    }

    return @intFromBool(!match);
}
