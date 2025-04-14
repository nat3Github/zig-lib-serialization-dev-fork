/// Provides symmetrical interfaces for both regular writers and bit writers
const std = @import("std");
const builtin = @import("builtin");
const Type = std.builtin.Type;

/// Whether type `T` is 0-bit at both comptime and runtime (void, u0, [0]T, etc.)
pub inline fn noData(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .null, .undefined, .void => true,
        .comptime_int,
        .comptime_float,
        .@"fn",
        .enum_literal,
        .frame,
        .@"anyframe",
        .@"opaque",
        => false,
        .int, .float => @bitSizeOf(T) == 0,
        .@"enum" => |e| noData(e.tag_type) or (e.fields.len <= 1 and e.is_exhaustive),
        .array => |a| a.len == 0 or noData(a.child),
        .vector => |a| a.len == 0 or noData(a.child),
        else => @bitSizeOf(T) == 0,
    };
}

/// Writes any integer to a `BitWriter`
/// Also works with values which can be @bitCast-ed into an unsigned integer of the same width (floats, packed structs, etc)
/// Writing counterpart to `bitReadInt`
/// Bit counterpart to `byteWriteInt`
pub fn bitWriteInt(bit_writer: anytype, comptime Int: type, int: Int) !void {
    if (noData(Int)) return;

    const U: type = @Type(.{ .int = .{
        .signedness = .unsigned,
        .bits = @bitSizeOf(Int),
    } });
    return bit_writer.writeBits(@as(U, @bitCast(int)), @bitSizeOf(Int));
}

/// Reads any integer from a `BitReader`
/// Returns an error on EOF
/// Also works with values which can be @bitCast-ed into an unsigned integer of the same width (floats, packed structs, etc)
/// Reading counterpart to `bitWriteInt`
/// Bit counterpart to `byteReadInt`
pub fn bitReadInt(bit_reader: anytype, comptime Int: type) !Int {
    if (noData(Int)) return @as(Int, undefined);

    const U: type = @Type(.{ .int = .{
        .signedness = .unsigned,
        .bits = @bitSizeOf(Int),
    } });
    return @bitCast(try bit_reader.readBitsNoEof(U, @bitSizeOf(U)));
}

/// Writes an enum from a `BitReader`
/// Writing counterpart to `bitReadEnum`
/// Bit counterpart to `byteWriteEnum`
pub fn bitWriteEnum(bit_writer: anytype, comptime Enum: type, tag: Enum) !void {
    const TagInt: type = @typeInfo(Enum).@"enum".tag_type;
    return bitWriteInt(bit_writer, TagInt, @intFromEnum(tag));
}

/// Reads an enum from a `BitReader`
/// Returns an error on EOF
/// Returns an error on an invalid tag
/// Reading counterpart to `bitWriteEnum`
/// Bit counterpart to `byteReadEnum`
pub fn bitReadEnum(bit_reader: anytype, comptime Enum: type) !Enum {
    const TagInt: type = @typeInfo(Enum).@"enum".tag_type;
    const tag_int: TagInt = try bitReadInt(bit_reader, TagInt);
    return std.meta.intToEnum(Enum, tag_int) catch error.Corrupt;
}

/// Writes any integer to a regular writer
/// Also works with values which can be @bitCast-ed into an unsigned integer of the same width (floats, packed structs, etc)
/// Writing counterpart to `byteReadInt`
/// Byte counterpart to `bitWriteInt`
pub fn byteWriteInt(writer: anytype, endian: std.builtin.Endian, comptime Int: type, int: Int) !void {
    if (noData(Int)) return;

    const U: type = @Type(.{ .int = .{
        .signedness = .unsigned,
        .bits = @bitSizeOf(Int),
    } });
    const B: type = std.math.ByteAlignedInt(U);
    return writer.writeInt(B, @as(U, @bitCast(int)), endian);
}

/// Reads any integer from a regular reader
/// Returns an error on EOF
/// Also works with values which can be @bitCast-ed into an unsigned integer of the same width (floats, packed structs, etc)
/// Reading counterpart to `byteWriteInt`
/// Byte counterpart to `bitReadInt`
pub fn byteReadInt(reader: anytype, endian: std.builtin.Endian, comptime Int: type) !Int {
    if (noData(Int)) return @as(Int, undefined);

    const U: type = @Type(.{ .int = .{
        .signedness = .unsigned,
        .bits = @bitSizeOf(Int),
    } });
    const B: type = std.math.ByteAlignedInt(U);

    const b: B = try reader.readInt(B, endian);

    if (@bitSizeOf(Int) == @bitSizeOf(B)) {
        return @bitCast(b);
    } else {
        return @bitCast(std.math.cast(U, b) orelse return error.Corrupt);
    }
}

/// Writes an enum to a regular writer
/// Writing counterpart to `byteReadEnum`
/// Byte counterpart to `bitWriteEnum`
pub fn byteWriteEnum(writer: anytype, endian: std.builtin.Endian, comptime Enum: type, tag: Enum) !void {
    const TagInt: type = @typeInfo(Enum).@"enum".tag_type;
    return byteWriteInt(writer, endian, TagInt, @intFromEnum(tag));
}

/// Reads an enum from a regular writer
/// Returns an error on EOF
/// Returns an error on an invalid tag
/// Reading counterpart to `byteWriteEnum`
/// Byte counterpart to `bitReadEnum`
pub fn byteReadEnum(reader: anytype, endian: std.builtin.Endian, comptime Enum: type) !Enum {
    const TagInt: type = @typeInfo(Enum).@"enum".tag_type;
    const tag_int: TagInt = try byteReadInt(reader, endian, TagInt);
    return std.meta.intToEnum(Enum, tag_int) catch error.Corrupt;
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
