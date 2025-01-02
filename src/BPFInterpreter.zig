// src/BPFInterpreter.zig
const std = @import("std");
const BPFRegisters = @import("logic.zig").BPFRegisters;

pub const BPFInterpreter = struct {
    registers: BPFRegisters,
    memory: []u8,
    stack: []u8,
    stack_ptr: usize,

    pub fn init(memory: []u8, stack: []u8) BPFInterpreter {
        return BPFInterpreter{
            .registers = BPFRegisters.init(),
            .memory = memory,
            .stack = stack,
            .stack_ptr = 0,
        };
    }

    pub const InterpreterError = error{
        UnknownOpcode,
        DivisionByZero,
        MemoryOutOfBounds,
        StackOverflow,
        StackUnderflow,
        InvalidJump,
        JITCompilationFailed,
        OutOfMemory,
    };

    // JIT compiler
    pub fn jitCompile(self: *BPFInterpreter, code: []const u8) InterpreterError!*const fn (*BPFInterpreter) void {
        _ = self;
        // Allocate executable memory for the generated code
        const code_size = code.len * 20; // Increase the size estimate
        const jit_code = try std.heap.page_allocator.alloc(u8, code_size);
        errdefer std.heap.page_allocator.free(jit_code);

        // Generate machine code
        var pc: usize = 0;
        var jit_pc: usize = 0;

        while (pc < code.len) {
            const opcode = code[pc];
            switch (opcode) {
                0x00 => { // ADD
                    // x86-64: add r0, r1
                    // Load r0 into RAX
                    jit_code[jit_pc] = 0x48; // REX.W prefix
                    jit_code[jit_pc + 1] = 0x8B; // MOV opcode
                    jit_code[jit_pc + 2] = 0x47; // ModR/M: [RDI + offset], RAX
                    jit_code[jit_pc + 3] = @as(u8, @intCast(@offsetOf(BPFInterpreter, "registers") + @offsetOf(BPFRegisters, "r0")));
                    jit_pc += 4;

                    // Load r1 into RCX
                    jit_code[jit_pc] = 0x48; // REX.W prefix
                    jit_code[jit_pc + 1] = 0x8B; // MOV opcode
                    jit_code[jit_pc + 2] = 0x4F; // ModR/M: [RDI + offset], RCX
                    jit_code[jit_pc + 3] = @as(u8, @intCast(@offsetOf(BPFInterpreter, "registers") + @offsetOf(BPFRegisters, "r1")));
                    jit_pc += 4;

                    // Add RCX to RAX
                    jit_code[jit_pc] = 0x48; // REX.W prefix
                    jit_code[jit_pc + 1] = 0x01; // ADD opcode
                    jit_code[jit_pc + 2] = 0xC8; // ModR/M: RAX += RCX
                    jit_pc += 3;

                    // Store RAX back into r0
                    jit_code[jit_pc] = 0x48; // REX.W prefix
                    jit_code[jit_pc + 1] = 0x89; // MOV opcode
                    jit_code[jit_pc + 2] = 0x47; // ModR/M: [RDI + offset], RAX
                    jit_code[jit_pc + 3] = @as(u8, @intCast(@offsetOf(BPFInterpreter, "registers") + @offsetOf(BPFRegisters, "r0")));
                    jit_pc += 4;

                    pc += 1;
                },
                0x12 => { // EXIT
                    // x86-64: ret
                    jit_code[jit_pc] = 0xC3; // RET opcode
                    jit_pc += 1;
                    pc += 1;
                },
                else => {
                    return InterpreterError.JITCompilationFailed;
                },
            }
        }

        // Make the generated code executable
        const result = std.os.linux.mprotect(
            @as([*]const u8, @ptrCast(jit_code.ptr)),
            jit_code.len,
            std.os.linux.PROT.EXEC | std.os.linux.PROT.READ,
        );
        if (result != 0) {
            return InterpreterError.OutOfMemory;
        }

        // Cast the generated code to a function pointer
        const jit_fn: *const fn (*BPFInterpreter) void = @ptrCast(@alignCast(jit_code.ptr));
        return jit_fn;
    }

    // Execute function with JIT compilation
    pub fn execute(self: *BPFInterpreter, code: []const u8) InterpreterError!void {
        // Try JIT compilation
        const jit_fn = self.jitCompile(code) catch |err| {
            std.debug.print("JIT compilation failed, falling back to interpreter: {}\n", .{err});
            return self.interpret(code);
        };

        // Execute the JIT-compiled code
        jit_fn(self);
    }

    // Interpreter fallback
    fn interpret(self: *BPFInterpreter, code: []const u8) InterpreterError!void {
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
                0x10 => { // JMP (Jump)
                    if (pc + 1 >= code.len) {
                        return InterpreterError.InvalidJump; // Bounds check
                    }
                    const offset = @as(i8, @bitCast(code[pc + 1])); // Read the offset (1 byte)
                    const new_pc = @as(usize, @intCast(@as(isize, @intCast(pc)) + offset)); // Calculate new PC
                    if (new_pc >= code.len) {
                        return InterpreterError.InvalidJump; // Bounds check
                    }
                    pc = new_pc; // Update PC
                },
                0x11 => { // CALL (Call)
                    if (pc + 1 >= code.len) {
                        return InterpreterError.InvalidJump; // Bounds check
                    }
                    const offset = @as(i8, @bitCast(code[pc + 1])); // Read the offset (1 byte)
                    const new_pc = @as(usize, @intCast(@as(isize, @intCast(pc)) + offset)); // Calculate new PC
                    if (new_pc >= code.len) {
                        return InterpreterError.InvalidJump; // Bounds check
                    }
                    // Push the return address (PC + 2) onto the stack
                    if (self.stack_ptr + 4 > self.stack.len) {
                        return InterpreterError.StackOverflow;
                    }
                    std.mem.writeInt(u32, self.stack[self.stack_ptr..][0..4], @as(u32, @intCast(pc + 2)), std.builtin.Endian.little);
                    self.stack_ptr += 4; // Move stack pointer forward
                    pc = new_pc; // Update PC
                },
                0x12 => { // EXIT (Exit)
                    return; // Terminate execution
                },

                else => {
                    std.debug.print("Unknown opcode: {}\n", .{opcode});
                    return InterpreterError.UnknownOpcode;
                },
            }
        }
    }

    pub fn verifyProgram(self: *BPFInterpreter, code: []const u8) bool {
        var pc: usize = 0;
        var has_exit = false;
        var stack_ptr: usize = 0; // Simulate stack pointer for verification

        while (pc < code.len) {
            const opcode = code[pc];
            switch (opcode) {
                0x09 => { // PUSH
                    if (stack_ptr + 4 > self.stack.len) {
                        std.debug.print("PUSH instruction causes stack overflow\n", .{});
                        return false;
                    }
                    stack_ptr += 4;
                    pc += 1;
                },
                0x0A => { // POP
                    if (stack_ptr < 4) {
                        std.debug.print("POP instruction causes stack underflow\n", .{});
                        return false;
                    }
                    stack_ptr -= 4;
                    pc += 1;
                },
                0x12 => { // EXIT
                    has_exit = true; // Mark that the program has an EXIT instruction
                    pc += 1;
                },
                else => {
                    pc += 1;
                },
            }
        }

        // Ensure the program has an EXIT instruction
        if (!has_exit) {
            std.debug.print("Program does not have an EXIT instruction\n", .{});
            return false;
        }

        return true;
    }
};
