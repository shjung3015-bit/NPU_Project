# Prompt for Claude Code — Accumulator module: create Adder, then verify

I've hand-written a new `src/Accumulator.sv` module (already in the repo). It
depends on a `src/Adder.sv` module that does NOT exist yet. Please:

## Step 1 — create src/Adder.sv

Simple combinational 32-bit signed adder, no clock/reset/enable needed:

```systemverilog
module Adder(
    input  logic signed [31:0] Data1,
    input  logic signed [31:0] Data2,
    output logic signed [31:0] dout
);
    assign dout = Data1 + Data2;
endmodule
```

## Step 2 — write a Verilator testbench for Accumulator

Add `tb/tb_Accumulator.sv` (follow the existing testbench style/conventions
in `tb/`) and drive the DUT directly (clk, rst_n, Core_Result, CoreResultValid,
AddEna) — no UART involved, this module doesn't touch UART_Bridge.

Two ports (`Pop`, `Output_Valid`) exist on the module but have NO logic
behind them yet — they're stubs for a future pop-out phase that isn't
implemented. Don't rely on them. Instead, observe results either via the
`dout` output (which is just a combinational passthrough of the internal
SRAM read output — valid the cycle after you drive `CoreResultValid` with
the address you want to inspect) or via hierarchical reference into the DUT
if that's easier.

Please verify these three things specifically:

1. **Write vs accumulate mode**: with `AddEna=0`, pushing a `Core_Result`
   through with `CoreResultValid` pulsed should just overwrite that address
   (no old value factored in). With `AddEna=1`, the same address should
   come out as `old_value + new_Core_Result`. Test both a single row and a
   handful of different addresses.

2. **Back-to-back pipeline timing**: pulse `CoreResultValid` on
   *consecutive* clock cycles (no gap) with different `Core_Result` values
   and different target addresses, and confirm every row lands correctly.
   Internally, `AddrWt`/`WriteEnable` are registered copies of
   `AddrRd`/`CoreResultValid` delayed by exactly one cycle to line up with
   the SRAM's own one-cycle read latency — this is the same class of
   off-by-one-cycle bug as the `FIFO_All` `.inject(start)` vs
   `.inject(Enb_act)` race we hit and fixed earlier this project, so please
   stress this specifically (don't just test isolated single pulses with
   gaps in between).

3. **Reset edge case**: assert `CoreResultValid` on the very first cycle
   after `rst_n` deasserts and confirm nothing corrupts (address counter
   starts at 0, no stale/undefined data gets written).

Report back: does it build cleanly, does each of the three scenarios pass,
and if something fails, what exactly broke (which address/cycle/value) —
don't just say "test failed."
