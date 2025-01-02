const std = @import("std");
const BPFInterpreter = @import("BPFInterpreter.zig").BPFInterpreter;

pub fn main() !void {
    // Initialize memory and stack
    var memory = [_]u8{0} ** 8; // 8-byte memory
    var stack = [_]u8{0} ** 8; // 8-byte stack

    // Initialize the interpreter
    var interpreter = BPFInterpreter.init(&memory, &stack);

    // Example BPF code: ADD and AND
    const code = [_]u8{
        0x00, // ADD: r0 += r1
        0x02, // AND: r0 &= r1
    };

    // Initialize registers
    interpreter.registers.r0 = 0b1100; // Example value for r0
    interpreter.registers.r1 = 0b1010; // Example value for r1

    // Execute the BPF program
    try interpreter.execute(&code);

    // Print the result
    std.debug.print("Result: {b}\n", .{interpreter.registers.r0});
}
