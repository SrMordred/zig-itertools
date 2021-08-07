const std = @import("std");

const span = std.mem.span;
const Span = std.mem.Span;
const Child = std.meta.Child;
const Allocator = std.mem.Allocator;

pub fn iterator(value: anytype) IterOf(@TypeOf(value)) {
    // Maybe there is a better way of doing this ?
    if (comptime IterOf(@TypeOf(value)) == @TypeOf(value)) {
        return value;
    } else {
        return IterOf(@TypeOf(value)).init(value);
    }
}

pub fn zip(input0: anytype, input1: anytype) ZipIter(IterOf(@TypeOf(input0)), IterOf(@TypeOf(input1))) {
    return ZipIter(IterOf(@TypeOf(input0)), IterOf(@TypeOf(input1))).init(iterator(input0), iterator(input1));
}

pub fn range(comptime _type: type, options: RangeOptions(_type)) RangeIter(_type) {
    return RangeIter(_type).init(options);
}

pub fn once(value: anytype) OnceIter(@TypeOf(value)) {
    return OnceIter(@TypeOf(value)).init(value);
}

pub fn Pair(comptime A: type, comptime B: type) type {
    return struct {
        const AType = A;
        const BType = B;
        a: AType,
        b: BType,
    };
}

pub fn pair(a: anytype, b: anytype) Pair(@TypeOf(a), @TypeOf(a)) {
    return Pair(@TypeOf(a), @TypeOf(a)){ .a = a, .b = b };
}

//  What I wanted on filter: self.Output.
//  But seems that with usingnamespace, the self type here are
//  unable to capture const members inside the parent struct
//  Because of that, the solution was to pass the Output explicitly
fn Functions(comptime Output: type) type {
    return struct {
        pub fn map(self: anytype, _fn: anytype) MapIter(@TypeOf(self), @TypeOf(_fn)) {
            return MapIter(@TypeOf(self), @TypeOf(_fn)).init(self, _fn);
        }

        pub fn filter(self: anytype, _fn: anytype) FilterIter(@TypeOf(self), Output, @TypeOf(_fn)) {
            return FilterIter(@TypeOf(self), Output, @TypeOf(_fn)).init(self, _fn);
        }

        pub fn reduce(self: anytype, _fn: anytype) OnceIter(Output) {
            if (self.next()) |first_value| {
                return OnceIter(Output).init(fold(self, first_value, _fn));
            } else {
                return OnceIter(Output).init(null);
            }
        }

        //  same problema that Input0.Output are not visible for some reason
        //  solved by passing the value instead of the pointer. (input0.*)
        //  I have no idea why it works, or if this will break something.
        pub fn zip(input0: anytype, input1: anytype) ZipIter(@TypeOf(input0.*), IterOf(@TypeOf(input1))) {
            return ZipIter(@TypeOf(input0.*), IterOf(@TypeOf(input1))).init(input0.*, iterator(input1));
        }

        // Consumers

        pub fn fold(self: anytype, start_value: anytype, _fn: anytype) Output {
            var accum: Output = start_value;
            while (self.next()) |value| {
                accum = _fn(accum, value);
            }
            return accum;
        }

        pub fn each(self: anytype, _fn: anytype) void {
            while (self.next()) |value| {
                _fn(value);
            }
        }

        pub fn toArrayList(self: anytype, allocator: *Allocator) !std.ArrayList(Output) {
            var array_list = std.ArrayList(Output).init(allocator);
            while (self.next()) |value| {
                try array_list.append(value);
            }
            return array_list;
        }

        pub fn toAutoHashMap(self: anytype, allocator: *Allocator) !std.AutoHashMap(Output.AType, Output.BType) {
            var array = std.AutoHashMap(Output.AType, Output.BType).init(allocator);
            while (self.next()) |value| {
                try array.put(value.a, value.b);
            }
            return array;
        }
    };
}

fn FnOutput(comptime Fn: type) type {
    //TODO: comptime check if is Fn type
    return @typeInfo(Fn).Fn.return_type.?;
}

fn IterOf(comptime Type: type) type {
    if (comptime std.meta.trait.hasFn("next")(Type)) {
        return Type;
    }

    const Info = @typeInfo(Type);
    return switch (Info) {
        .Pointer => |pointer| switch (pointer.size) {
            .One => return switch (@typeInfo(pointer.child)) {
                .Array => SliceIter(Span(Type)),
                else => @compileError("IterOf(" ++ @typeName(Type) ++ ") not implemented!"),
            },
            else => @compileError("IterOf(" ++ @typeName(Type) ++ ") not implemented!"),
        },
        else => @compileError("IterOf(" ++ @typeName(Type) ++ ") not implemented!"),
    };
}

fn OnceIter(comptime Type: type) type {
    return struct {
        const Self = @This();
        pub const Output = Type;
        value: ?Type,

        fn init(value: ?Type) Self {
            return Self{ .value = value };
        }

        pub fn next(self: *Self) ?Output {
            if (self.value) |value| {
                defer self.value = null;
                return value;
            } else {
                return null;
            }
        }

        usingnamespace Functions(Output);
    };
}

fn SliceIter(comptime Slice: type) type {
    return struct {
        const Self = @This();
        pub const Output = Child(Slice);
        data: Slice,
        fn init(data: Slice) Self {
            return Self{ .data = data };
        }

        pub fn next(self: *Self) ?Output {
            if (self.data.len == 0) {
                return null;
            }
            defer self.data = self.data[1..];
            return self.data[0];
        }

        usingnamespace Functions(Output);
    };
}

fn RangeOptions(comptime _type: type) type {
    return struct { start: _type = 0, end: _type = 0, step: _type = 1 };
}

fn RangeIter(comptime Type: type) type {
    return struct {
        const Self = @This();
        pub const Output = Type;

        start: Output,
        end: Output,
        step: Output,

        fn init(options: RangeOptions(Output)) Self {
            return Self{
                .start = options.start,
                .end = options.end,
                .step = options.step,
            };
        }

        pub fn next(self: *Self) ?Output {
            if (self.start >= self.end) {
                return null;
            }
            defer self.start += self.step;
            return self.start;
        }

        usingnamespace Functions(Output);
    };
}

fn MapIter(comptime Input: type, comptime Fn: type) type {
    return struct {
        const Self = @This();
        pub const Output = FnOutput(Fn);

        input: Input,
        _fn: Fn,

        fn init(input: Input, _fn: Fn) Self {
            return Self{ .input = input, ._fn = _fn };
        }

        pub fn next(self: *Self) ?Output {
            if (self.input.next()) |value| {
                return self._fn(value);
            } else {
                return null;
            }
        }

        usingnamespace Functions(Output);
    };
}

fn FilterIter(comptime Input: type, comptime _Output: type, comptime Fn: type) type {
    return struct {
        const Self = @This();
        const Output = _Output;

        input: Input,
        _fn: Fn,

        fn init(input: Input, _fn: Fn) Self {
            return Self{ .input = input, ._fn = _fn };
        }

        pub fn next(self: *Self) ?Output {
            while (self.input.next()) |value| {
                if (self._fn(value)) {
                    return value;
                }
            }
            return null;
        }

        usingnamespace Functions(Output);
    };
}

fn ZipIter(comptime Input0: type, comptime Input1: type) type {
    return struct {
        const Self = @This();
        const Output = Pair(Input0.Output, Input1.Output);

        input0: Input0,
        input1: Input1,

        fn init(input0: Input0, input1: Input1) Self {
            return Self{ .input0 = input0, .input1 = input1 };
        }

        pub fn next(self: *Self) ?Output {
            if (self.input0.next()) |a| {
                if (self.input1.next()) |b| {
                    return Output{ .a = a, .b = b };
                }
            }
            return null;
        }

        usingnamespace Functions(Output);
    };
}
