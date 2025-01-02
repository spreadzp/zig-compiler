
# UML schema BPF compiler

```mermaid 
classDiagram
    class BPFInterpreter {
        + registers: BPFRegisters
        + memory: []u8
        + stack: []u8
        + stack_ptr: usize

        + init(memory: []u8, stack: []u8): BPFInterpreter
        + execute(code: []const u8): InterpreterError!void
        + verifyProgram(code: []const u8): bool
    }

    class BPFRegisters {
        + r0: u32
        + r1: u32
        + r2: u32
        + r3: u32
        + r4: u32
        + r5: u32
        + r6: u32
        + r7: u32
        + r8: u32
        + r9: u32
        + r10: u32

        + init(): BPFRegisters
    }

    BPFInterpreter --> BPFRegisters: "uses"
    BPFInterpreter --> "memory": "accesses"
    BPFInterpreter --> "stack": "accesses"

    class Main {
        + main(): void
    }

    Main --> BPFInterpreter: "uses"

```

# Tests commands 
```bash
zig build test
zig test src/tests/test.zig -I src --mod bpf:src/BPFInterpreter.zig



```