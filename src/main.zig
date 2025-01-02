const std = @import("std");
const BPFInterpreter = @import("BPFInterpreter.zig").BPFInterpreter;

pub fn main() void {
    var memory = [_]u8{0} ** 12; // 12-byte memory
    var stack = [_]u8{0} ** 12; // 12-byte stack
    var interpreter = BPFInterpreter.init(&memory, &stack);
    const code = [_]u8{ 0x00, 0x02, 0x12 }; // Пример BPF-кода (ADD , AND, EXIT)
    const valid = interpreter.verifyProgram(&code);

    std.debug.print("Result: {}\n", .{valid});
}
