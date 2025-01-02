// src/BPFInterpreter.zig
const std = @import("std");
const BPFRegisters = @import("logic.zig").BPFRegisters;

pub const BPFInterpreter = struct {
    registers: BPFRegisters,
    memory: []u8, // Change to mutable slice
    stack: []u8, // Add a stack
    stack_ptr: usize,

    pub fn init(memory: []u8, stack: []u8) BPFInterpreter {
        return BPFInterpreter{
            .registers = BPFRegisters.init(),
            .memory = memory,
            .stack = stack,
            .stack_ptr = 0, // Initialize stack pointer to 0
        };
    }

    pub const InterpreterError = error{ UnknownOpcode, DivisionByZero, MemoryOutOfBounds, StackOverflow, StackUnderflow };

    pub fn execute(self: *BPFInterpreter, code: []const u8) InterpreterError!void {
        var pc: usize = 0;
        while (pc < code.len) {
            const opcode = code[pc];
            switch (opcode) {
                0x00 => { // ADD
                    self.registers.r0 += self.registers.r1;
                    pc += 1;
                },
                0x01 => { // SUB
                    self.registers.r0 -= self.registers.r1;
                    pc += 1;
                },
                0x02 => { // AND
                    self.registers.r0 &= self.registers.r1;
                    pc += 1;
                },
                0x03 => { // MUL
                    self.registers.r0 *= self.registers.r1;
                    pc += 1;
                },
                0x04 => { // DIV
                    if (self.registers.r1 == 0) {
                        return InterpreterError.DivisionByZero;
                    }
                    self.registers.r0 /= self.registers.r1;
                    pc += 1;
                },
                0x05 => { // LD (Load)
                    const address = self.registers.r1;
                    if (address + 4 > self.memory.len) {
                        return InterpreterError.MemoryOutOfBounds;
                    }
                    self.registers.r0 = std.mem.readInt(u32, self.memory[address..][0..4], std.builtin.Endian.little);
                    pc += 1;
                },
                0x06 => { // ST (Store)
                    const address = self.registers.r1;
                    if (address + 4 > self.memory.len) {
                        return InterpreterError.MemoryOutOfBounds;
                    }
                    std.mem.writeInt(u32, self.memory[address..][0..4], self.registers.r0, std.builtin.Endian.little);
                    pc += 1;
                },
                0x07 => { // OR
                    self.registers.r0 |= self.registers.r1;
                    pc += 1;
                },
                0x08 => { // XOR
                    self.registers.r0 ^= self.registers.r1;
                    pc += 1;
                },
                0x09 => { // PUSH
                    if (self.stack_ptr + 4 > self.stack.len) {
                        return InterpreterError.StackOverflow;
                    }
                    std.mem.writeInt(u32, self.stack[self.stack_ptr..][0..4], self.registers.r0, std.builtin.Endian.little);
                    self.stack_ptr += 4; // Move stack pointer forward
                    pc += 1;
                },
                0x0A => { // POP
                    if (self.stack_ptr < 4) {
                        return InterpreterError.StackUnderflow;
                    }
                    self.stack_ptr -= 4; // Move stack pointer backward
                    self.registers.r0 = std.mem.readInt(u32, self.stack[self.stack_ptr..][0..4], std.builtin.Endian.little);
                    pc += 1;
                },

                else => {
                    std.debug.print("Unknown opcode: {}\n", .{opcode});
                    return InterpreterError.UnknownOpcode;
                },
            }
        }
    }

    pub fn verifyProgram(self: *BPFInterpreter, code: []const u8) bool {
        _ = self;
        var pc: usize = 0;
        while (pc < code.len) {
            const opcode = code[pc];
            switch (opcode) {
                0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A => { // Valid opcodes: ADD, SUB, AND, MUL, DIV...
                    pc += 1;
                },
                else => {
                    std.debug.print("Invalid opcode: {}\n", .{opcode});
                    return false;
                },
            }
        }
        return true;
    }
};
