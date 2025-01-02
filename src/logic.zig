const std = @import("std");

pub const BPFRegisters = struct {
    r0: u32,
    r1: u32,
    r2: u32,
    r3: u32,
    r4: u32,
    r5: u32,
    r6: u32,
    r7: u32,
    r8: u32,
    r9: u32,
    r10: u32,

    pub fn init() BPFRegisters {
        return BPFRegisters{
            .r0 = 0,
            .r1 = 0,
            .r2 = 0,
            .r3 = 0,
            .r4 = 0,
            .r5 = 0,
            .r6 = 0,
            .r7 = 0,
            .r8 = 0,
            .r9 = 0,
            .r10 = 0,
        };
    }
};
