const std = @import("std");

usingnamespace @import("itertools.zig");

const IsEqual = std.testing.expectEqual;

test "range" {
    {
        var range_iter = range(i32, .{ .start = 0, .end = 5, .step = 1 });
        var total: i32 = 0;

        while (range_iter.next()) |value| {
            total += value;
        }

        try IsEqual(total, 10);
    }

    {
        // missing fields, fine but dont iterate
        var range_iter = range(i32, .{});
        var total: i32 = 0;

        while (range_iter.next()) |value| {
            total += value;
        }

        try IsEqual(total, 0);
    }

    {
        // missing fields, fine but dont iterate
        var range_iter = range(i32, .{ .end = 10 });
        var total: i32 = 0;
        while (range_iter.next()) |value| {
            total += value;
        }

        try IsEqual(total, 45);
    }

    {
        var range_iter = range(i32, .{ .end = 10, .step = 2 });
        var total: i32 = 0;
        while (range_iter.next()) |value| {
            total += value;
        }
        //2 + 4 + 6 + 8 = 20
        try IsEqual(total, 20);
    }
}

test "slice to iter" {
    const arr = [_]u32{ 1, 2, 3 };
    var iter = iterator(&arr);

    try IsEqual(iter.next().?, 1);
    try IsEqual(iter.next().?, 2);
    try IsEqual(iter.next().?, 3);
    try IsEqual(iter.next(), null);
}

fn double(a: i32) i32 {
    return a * 2;
}

test "map" {
    const arr = [_]i32{ 1, 2, 3 };
    var iter = iterator(&arr).map(double);

    try IsEqual(iter.next().?, 2);
    try IsEqual(iter.next().?, 4);
    try IsEqual(iter.next().?, 6);
    try IsEqual(iter.next(), null);
}

fn odd(a: i32) bool {
    return @mod(a, 2) == 1;
}

test "filter" {
    const arr = [_]i32{ 1, 2, 3, 4, 5, 6 };
    var iter = iterator(&arr).filter(odd);

    try IsEqual(iter.next().?, 1);
    try IsEqual(iter.next().?, 3);
    try IsEqual(iter.next().?, 5);
    try IsEqual(iter.next(), null);
}

fn sum(a: i32, b: i32) i32 {
    return a + b;
}

test "reduce" {
    const arr = [_]i32{ 1, 2, 3, 4, 5, 6 };
    var iter = iterator(&arr).reduce(sum); // 21

    try IsEqual(iter.next().?, 21);
    try IsEqual(iter.next(), null);
}

test "fold" {
    const arr = [_]i32{ 1, 2, 3, 4, 5, 6 };
    var result = iterator(&arr).fold(10, sum); // 10 + 21, fold is eager

    try IsEqual(result, 31);
}

test "zip" {
    {
        const arr = [_]i32{ 1, 2, 3 };
        const arr2 = [_]i32{ 4, 5, 6 };
        var iter = iterator(&arr).zip(&arr2);

        try IsEqual(iter.next().?, pair(@as(i32, 1), @as(i32, 4)));
        try IsEqual(iter.next().?, pair(@as(i32, 2), @as(i32, 5)));
        try IsEqual(iter.next().?, pair(@as(i32, 3), @as(i32, 6)));
        try IsEqual(iter.next(), null);
    }

    {
        const arr = [_]i32{ 1, 2, 3 };
        const arr2 = [_]i32{ 4, 5, 6 };
        var iter = zip(&arr, &arr2);

        try IsEqual(iter.next().?, pair(@as(i32, 1), @as(i32, 4)));
        try IsEqual(iter.next().?, pair(@as(i32, 2), @as(i32, 5)));
        try IsEqual(iter.next().?, pair(@as(i32, 3), @as(i32, 6)));
        try IsEqual(iter.next(), null);
    }
}

test "toArrayList" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = &gpa.allocator;

    var array_list = try range(i32, .{ .end = 10, .step = 2 }).toArrayList(alloc);

    try IsEqual(array_list.items[0], 0);
    try IsEqual(array_list.items[1], 2);
    try IsEqual(array_list.items[2], 4);
    try IsEqual(array_list.items[3], 6);
    try IsEqual(array_list.items[4], 8);
}

test "toAutoHashMap" {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // var alloc = &gpa.allocator;

    // const key = [_]i32{ 1, 2, 3 };
    // const value = [_][]const u8{ "One", "Two", "Three" };
    // var dict = try zip(&key, &value).toAutoHashMap(alloc);

    // how to properly test this ??
}

test "once" {
    var iter = once(@as(i32, 10)).map(double);

    try IsEqual(iter.next().?, 20);
    try IsEqual(iter.next(), null);
}

fn printer(a: anytype) void {
    std.debug.print("{}\n", .{a});
}

fn divBy10(a: i32) bool {
    return @mod(a, 10) == 0;
}

test "multiple iterators" {
    var result = range(i32, .{ .end = 100 }).map(double).filter(divBy10).fold(100, sum);

    try IsEqual(result, 2000);
}
