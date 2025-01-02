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

// Helper function to print the free space in the stack
fn printStackFreeSpace(interpreter: *BPFInterpreter) void {
    const free_space = interpreter.stack.len - interpreter.stack_ptr;
    std.debug.print("Free stack space: {} bytes\n", .{free_space});
}

test "Verifier (valid program)" {
    var memory = [_]u8{ 0x01, 0x00, 0x00, 0x00 };
    var stack = [_]u8{0} ** 1024; // Add a stack
    var interpreter = BPFInterpreter.init(&memory, &stack);
    const code = [_]u8{ 0x00, 0x01, 0x02, 0x03, 0x04 }; // ADD, SUB, AND, MUL, DIV
    const valid = interpreter.verifyProgram(&code);
    printTestResult("Verifier (valid program)", valid);
    try std.testing.expect(valid);
}

test "Verifier (invalid program)" {
    var memory = [_]u8{ 0x01, 0x00, 0x00, 0x00 };
    var stack = [_]u8{0} ** 1024; // Add a stack
    var interpreter = BPFInterpreter.init(&memory, &stack);
    const code = [_]u8{0xFF}; // Unknown opcode
    const valid = interpreter.verifyProgram(&code);
    printTestResult("Verifier (invalid program)", !valid);
    try std.testing.expect(!valid);
}

test "ADD instruction" {
    var memory = [_]u8{};
    var stack = [_]u8{0} ** 1024; // Add a stack
    var interpreter = BPFInterpreter.init(&memory, &stack);
    interpreter.registers.r0 = 5;
    interpreter.registers.r1 = 3;

    const code = [_]u8{0x00}; // ADD
    try interpreter.execute(&code);

    const passed = interpreter.registers.r0 == 8;
    printTestResult("ADD instruction", passed);
    try std.testing.expect(passed);
}

test "OR instruction" {
    var memory = [_]u8{};
    var stack = [_]u8{0} ** 1024; // Add a stack
    var interpreter = BPFInterpreter.init(&memory, &stack);
    interpreter.registers.r0 = 0b1100;
    interpreter.registers.r1 = 0b1010;

    const code = [_]u8{0x07}; // OR
    try interpreter.execute(&code);

    const passed = interpreter.registers.r0 == 0b1110;
    printTestResult("OR instruction", passed);
    try std.testing.expect(passed);
}

test "AND instruction" {
    var memory = [_]u8{ 0x01, 0x00, 0x00, 0x00 };
    var stack = [_]u8{0} ** 1024; // Add a stack
    var interpreter = BPFInterpreter.init(&memory, &stack);
    interpreter.registers.r0 = 0b1100;
    interpreter.registers.r1 = 0b1010;

    const code = [_]u8{0x02}; // AND
    try interpreter.execute(&code);

    const passed = interpreter.registers.r0 == 0b1000;
    printTestResult("AND instruction", passed);
    try std.testing.expect(passed);
}

test "SUB instruction" {
    var memory = [_]u8{ 0x01, 0x00, 0x00, 0x00 };
    var stack = [_]u8{0} ** 1024; // Add a stack
    var interpreter = BPFInterpreter.init(&memory, &stack);
    interpreter.registers.r0 = 10;
    interpreter.registers.r1 = 4;

    const code = [_]u8{0x01}; // SUB
    try interpreter.execute(&code);

    const passed = interpreter.registers.r0 == 6;
    printTestResult("SUB instruction", passed);
    try std.testing.expect(passed);
}

test "Division by zero" {
    var memory = [_]u8{};
    var stack = [_]u8{0} ** 1024; // Add a stack
    var interpreter = BPFInterpreter.init(&memory, &stack);
    interpreter.registers.r0 = 10;
    interpreter.registers.r1 = 0;

    const code = [_]u8{0x04}; // DIV
    const result = interpreter.execute(&code);
    const passed = result == BPFInterpreter.InterpreterError.DivisionByZero;
    printTestResult("Division by zero", passed);
    try std.testing.expect(passed);
}

test "MUL instruction" {
    var memory = [_]u8{ 0x01, 0x00, 0x00, 0x00 };
    var stack = [_]u8{0} ** 1024; // Add a stack
    var interpreter = BPFInterpreter.init(&memory, &stack);
    interpreter.registers.r0 = 5;
    interpreter.registers.r1 = 3;

    const code = [_]u8{0x03}; // MUL
    try interpreter.execute(&code);

    const passed = interpreter.registers.r0 == 15;
    printTestResult("MUL instruction", passed);
    try std.testing.expect(passed);
}

test "Unknown opcode" {
    var memory = [_]u8{ 0x01, 0x00, 0x00, 0x00 };
    var stack = [_]u8{0} ** 1024; // Add a stack
    var interpreter = BPFInterpreter.init(&memory, &stack);
    const code = [_]u8{0xFF}; // Unknown opcode

    const result = interpreter.execute(&code);
    const passed = result == BPFInterpreter.InterpreterError.UnknownOpcode;
    printTestResult("Unknown opcode", passed);
    try std.testing.expect(passed);
}

test "LD instruction" {
    var memory = [_]u8{ 0x01, 0x00, 0x00, 0x00 }; // Little-endian 32-bit value: 1
    var stack = [_]u8{0} ** 1024; // Add a stack
    var interpreter = BPFInterpreter.init(&memory, &stack);
    interpreter.registers.r1 = 0; // Address to load from

    const code = [_]u8{0x05}; // LD
    try interpreter.execute(&code);

    const passed = interpreter.registers.r0 == 1;
    printTestResult("LD instruction", passed);
    try std.testing.expect(passed);
}

test "ST instruction" {
    var memory = [_]u8{ 0x00, 0x00, 0x00, 0x00 }; // Initialize memory to 0
    var stack = [_]u8{0} ** 1024; // Add a stack
    var interpreter = BPFInterpreter.init(&memory, &stack);
    interpreter.registers.r0 = 1; // Value to store
    interpreter.registers.r1 = 0; // Address to store at

    const code = [_]u8{0x06}; // ST
    try interpreter.execute(&code);

    const passed = std.mem.readInt(u32, memory[0..4], std.builtin.Endian.little) == 1;
    printTestResult("ST instruction", passed);
    try std.testing.expect(passed);
}

test "Stack overflow" {
    var memory = [_]u8{};
    var stack = [_]u8{0} ** 3; // Small stack (only 3 bytes)
    var interpreter = BPFInterpreter.init(&memory, &stack);
    interpreter.registers.r0 = 1;

    const code = [_]u8{0x09}; // PUSH
    const result = interpreter.execute(&code);
    std.debug.print("@@@@@Stack overflow '{any}' ", .{result});
    // Check if the result is the expected error
    const passed = if (result) |_| false else |err| err == BPFInterpreter.InterpreterError.StackOverflow;
    printTestResult("Stack overflow", passed);
    try std.testing.expect(passed);
}

test "Stack underflow" {
    var memory = [_]u8{};
    var stack = [_]u8{0} ** 0; // Empty stack
    var interpreter = BPFInterpreter.init(&memory, &stack);

    const code = [_]u8{0x0A}; // POP
    const result = interpreter.execute(&code);
    std.debug.print("@@@@@Stack underflow '{any}' ", .{result});

    // Check if the result is the expected error
    const passed = if (result) |_| false else |err| err == BPFInterpreter.InterpreterError.StackUnderflow;
    printTestResult("Stack underflow", passed);
}

test "XOR instruction" {
    var memory = [_]u8{};
    var stack = [_]u8{0} ** 1024; // Add a stack
    var interpreter = BPFInterpreter.init(&memory, &stack);
    interpreter.registers.r0 = 0b1100;
    interpreter.registers.r1 = 0b1010;

    const code = [_]u8{0x08}; // XOR
    try interpreter.execute(&code);

    const passed = interpreter.registers.r0 == 0b0110;
    printTestResult("XOR instruction", passed);
    try std.testing.expect(passed);
}

test "Stack operations" {
    var memory = [_]u8{};
    var stack = [_]u8{0} ** 8; // 8-byte stack
    var interpreter = BPFInterpreter.init(&memory, &stack);

    // Initial stack free space
    printStackFreeSpace(&interpreter);

    // Push two values onto the stack
    interpreter.registers.r0 = 1;
    try interpreter.execute(&[_]u8{0x09}); // PUSH
    printStackFreeSpace(&interpreter); // Print free space after first push

    interpreter.registers.r0 = 2;
    try interpreter.execute(&[_]u8{0x09}); // PUSH
    printStackFreeSpace(&interpreter); // Print free space after second push

    // Pop the values and verify
    try interpreter.execute(&[_]u8{0x0A}); // POP
    const passed1 = interpreter.registers.r0 == 2;
    printStackFreeSpace(&interpreter); // Print free space after first pop

    try interpreter.execute(&[_]u8{0x0A}); // POP
    const passed2 = interpreter.registers.r0 == 1;
    printStackFreeSpace(&interpreter); // Print free space after second pop

    // Verify that the stack is now empty
    const passed3 = interpreter.stack_ptr == 0;
    printStackFreeSpace(&interpreter); // Print free space after all operations

    const passed = passed1 and passed2 and passed3;
    printTestResult("Stack operations", passed);
    try std.testing.expect(passed);
}

test "JMP instruction" {
    var memory = [_]u8{};
    var stack = [_]u8{0} ** 8; // 8-byte stack
    var interpreter = BPFInterpreter.init(&memory, &stack);

    // Program: JMP +2, ADD, EXIT
    const code = [_]u8{ 0x10, 0x02, 0x00, 0x12 };
    try interpreter.execute(&code);

    // Verify that the JMP skipped the ADD instruction
    const passed = interpreter.registers.r0 == 0; // r0 should remain 0
    printTestResult("JMP instruction", passed);
    try std.testing.expect(passed);
}

test "CALL and RETURN instructions" {
    var memory = [_]u8{};
    var stack = [_]u8{0} ** 8; // 8-byte stack
    var interpreter = BPFInterpreter.init(&memory, &stack);

    // Program: CALL +3, EXIT, ADD, EXIT
    const code = [_]u8{ 0x11, 0x03, 0x12, 0x00, 0x12 };
    interpreter.registers.r0 = 5;
    interpreter.registers.r1 = 3;
    try interpreter.execute(&code);

    // Verify that the CALL executed the ADD instruction and returned
    const passed = interpreter.registers.r0 == 8; // r0 should be 5 + 3 = 8
    printTestResult("CALL and RETURN instructions", passed);
    try std.testing.expect(passed);
}

test "EXIT instruction" {
    var memory = [_]u8{};
    var stack = [_]u8{0} ** 8; // 8-byte stack
    var interpreter = BPFInterpreter.init(&memory, &stack);

    // Program: EXIT, ADD
    const code = [_]u8{ 0x12, 0x00 };
    interpreter.registers.r0 = 5;
    interpreter.registers.r1 = 3;
    try interpreter.execute(&code);

    // Verify that the EXIT instruction terminated the program
    const passed = interpreter.registers.r0 == 5; // r0 should remain 5
    printTestResult("EXIT instruction", passed);
    try std.testing.expect(passed);
}
