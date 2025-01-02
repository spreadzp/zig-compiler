// src/test.zig
const std = @import("std");
const BPFInterpreter = @import("BPFInterpreter.zig").BPFInterpreter;

// ANSI escape codes for colors
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const RESET = "\x1b[0m";

fn printTestResult(name: []const u8, passed: bool) void {
    if (passed) {
        std.debug.print(GREEN ++ "PASS" ++ RESET ++ ": {s}\n", .{name});
    } else {
        std.debug.print(RED ++ "FAIL" ++ RESET ++ ": {s}\n", .{name});
    }
}

test "Verifier (valid program)" {
    var memory = [_]u8{ 0x01, 0x00, 0x00, 0x00 }; // Use `var` instead of `const`
    var interpreter = BPFInterpreter.init(&memory); // Use & here
    const code = [_]u8{ 0x00, 0x01, 0x02, 0x03, 0x04 }; // ADD, SUB, AND, MUL, DIV
    const valid = interpreter.verifyProgram(&code);
    printTestResult("Verifier (valid program)", valid);
    try std.testing.expect(valid);
}

test "Verifier (invalid program)" {
    var memory = [_]u8{ 0x01, 0x00, 0x00, 0x00 }; // Use `var` instead of `const`
    var interpreter = BPFInterpreter.init(&memory); // Use & here
    const code = [_]u8{0xFF}; // Unknown opcode
    const valid = interpreter.verifyProgram(&code);
    printTestResult("Verifier (invalid program)", !valid);
    try std.testing.expect(!valid);
}

test "ADD instruction" {
    var memory = [_]u8{}; // Use `var` instead of `const`
    var interpreter = BPFInterpreter.init(&memory); // Use & here
    interpreter.registers.r0 = 5;
    interpreter.registers.r1 = 3;

    const code = [_]u8{0x00}; // ADD
    try interpreter.execute(&code);

    const passed = interpreter.registers.r0 == 8;
    printTestResult("ADD instruction", passed);
    try std.testing.expect(passed);
}

test "AND instruction" {
    var memory = [_]u8{ 0x01, 0x00, 0x00, 0x00 }; // Use `var` instead of `const`
    var interpreter = BPFInterpreter.init(&memory); // Use & here
    interpreter.registers.r0 = 0b1100;
    interpreter.registers.r1 = 0b1010;

    const code = [_]u8{0x02}; // AND
    try interpreter.execute(&code);

    const passed = interpreter.registers.r0 == 0b1000;
    printTestResult("AND instruction", passed);
    try std.testing.expect(passed);
}

test "SUB instruction" {
    var memory = [_]u8{ 0x01, 0x00, 0x00, 0x00 }; // Use `var` instead of `const`
    var interpreter = BPFInterpreter.init(&memory); // Use & here
    interpreter.registers.r0 = 10;
    interpreter.registers.r1 = 4;

    const code = [_]u8{0x01}; // SUB
    try interpreter.execute(&code);

    const passed = interpreter.registers.r0 == 6;
    printTestResult("SUB instruction", passed);
    try std.testing.expect(passed);
}

test "MUL instruction" {
    var memory = [_]u8{ 0x01, 0x00, 0x00, 0x00 }; // Use `var` instead of `const`
    var interpreter = BPFInterpreter.init(&memory); // Use & here
    interpreter.registers.r0 = 5;
    interpreter.registers.r1 = 3;

    const code = [_]u8{0x03}; // MUL
    try interpreter.execute(&code);

    const passed = interpreter.registers.r0 == 15;
    printTestResult("MUL instruction", passed);
    try std.testing.expect(passed);
}

test "Unknown opcode" {
    var memory = [_]u8{ 0x01, 0x00, 0x00, 0x00 }; // Use `var` instead of `const`
    var interpreter = BPFInterpreter.init(&memory); // Use & here
    const code = [_]u8{0xFF}; // Unknown opcode

    const result = interpreter.execute(&code);
    const passed = result == BPFInterpreter.InterpreterError.UnknownOpcode;
    printTestResult("Unknown opcode", passed);
    try std.testing.expect(passed);
}

test "LD instruction" {
    var memory = [_]u8{ 0x01, 0x00, 0x00, 0x00 }; // Little-endian 32-bit value: 1
    var interpreter = BPFInterpreter.init(&memory);
    interpreter.registers.r1 = 0; // Address to load from

    const code = [_]u8{0x05}; // LD
    try interpreter.execute(&code);

    const passed = interpreter.registers.r0 == 1;
    printTestResult("LD instruction", passed);
    try std.testing.expect(passed);
}

test "ST instruction" {
    var memory = [_]u8{ 0x00, 0x00, 0x00, 0x00 }; // Initialize memory to 0
    var interpreter = BPFInterpreter.init(&memory);
    interpreter.registers.r0 = 1; // Value to store
    interpreter.registers.r1 = 0; // Address to store at

    const code = [_]u8{0x06}; // ST
    try interpreter.execute(&code);

    const passed = std.mem.readInt(u32, memory[0..4], std.builtin.Endian.little) == 1;
    printTestResult("ST instruction", passed);
    try std.testing.expect(passed);
}
