const std = @import("std");
const BPFInterpreter = @import("BPFInterpreter.zig").BPFInterpreter;

pub fn main() void {
    var interpreter = BPFInterpreter.init();
    const code = [_]u8{ 0x00, 0x02 }; // Пример BPF-кода (ADD и AND)
    interpreter.execute(&code);

    std.debug.print("Result: {}\n", .{interpreter.registers.r0});
}
