# Coding Conventions

This file documents the two naming/coding rules the RTL in `src/`, `sva/`, and `tb/` follows. Apply both rules to any new signal or parameter added to this project so the codebase stays consistent.

## 1. Parameterization

Any number that is reused, that sizes a memory/bus/array, or that encodes a register-map/opcode value must be a named `parameter` or `localparam`, never a bare literal repeated in multiple places.

- Name style: `ALL_CAPS_SNAKE_CASE` (e.g. `ARRAY_SIZE`, `ADDR_W`)
- Prefer `localparam` unless the module is genuinely meant to be instantiated with different sizes (nothing in this design is today).
- Where a parameter's value is derived from another (e.g. a pointer width from a depth), write the derivation instead of a second literal:
  ```systemverilog
  localparam FIFO_DEPTH = 8;
  localparam PTR_W      = $clog2(FIFO_DEPTH);
  ```
- One-off structural literals that encode a fixed hand-unrolled shape (e.g. the triangular skew-buffer indices in `SKEW_Unit`, or the exact `genvar` indices in a generate block) are not "magic numbers" in this sense and are left as literals — rewriting them as expressions adds risk without adding reuse.

**Examples already in the codebase:**

| File | Parameters |
|---|---|
| `SRAM.sv` | `ADDR_W`, `DATA_W`, `DEPTH` |
| `FIFO.sv` | `FIFO_DEPTH`, `DATA_W`, `PTR_W` |
| `FIFO_All.sv` | `NUM_LANES`, `FIFO_DEPTH` |
| `Systolic_Array` | `ARRAY_SIZE` |
| `Controller.sv` | `ARRAY_SIZE`, `ADDR_W` |
| `MAC_Unit.sv` | `ACT_W`, `PSUM_W` |
| `UART_Bridge.sv` | `REG_CTRL` .. `REG_RESULT` (register map), `NUM_LANES`, `RESULT_BYTES`, `MAX_WRITE_BYTES` |

## 2. Variable Naming Rule

Applies to every net/reg/port (i.e. anything that holds a value) — **not** to parameters/localparams (rule 1 above covers those) and **not** to module or instance names (e.g. `U_Bridge`, `SRAM_wgt`, `PE` are left alone).

Style: a Pascal+Snake hybrid. Multi-word concepts are merged into PascalCase; an underscore is used ONLY to attach a domain qualifier (`act` = activation path, `wgt` = weight path) to the end of a name.

```
load_en        -> LoadEna          (two words, same concept -> merge)
base_addr_act  -> BaseAddr_act     ("BaseAddr" + activation-domain tag)
base_addr_wgt  -> BaseAddr_wgt     ("BaseAddr" + weight-domain tag)
```

**Mechanical algorithm** (apply this to any new signal name):

1. Split the name on its existing underscores into tokens.
2. If there's only one token, leave it alone — it's already atomic (`clk`, `run`, `busy`, `wea`, `addr`, `ena`, `mem`, `cmd`, `dout`, `wptr`, `rptr`, ...).
3. If the token `act` or `wgt` appears anywhere in the list (including the middle), pull it out and remember it as the *domain* — the domain always ends up trailing, even if it didn't start there (e.g. `addr_act_wt` -> `AddrWt_act`, not `Addr_act_wt`).
4. Normalize the bare token `en` to `ena` (the approved enable abbreviation).
5. PascalCase-join whatever tokens are left (the "core"), with no underscore between them.
6. If a domain was captured in step 3, append `_act` or `_wgt` (lowercase) to the PascalCase core.

**Approved abbreviations** (kept lowercase, used freely as a token):

| Abbreviation | Meaning | Abbreviation | Meaning |
|---|---|---|---|
| `wea` | write enable | `ena` | enable |
| `addr` | address | `reg` | register |

(plus already-standard short tokens treated the same way: `clk`, `rst_n`, `rx`, `tx`, `wgt`, `act`, `psum`, `din`, `dout`, `ptr`, `cmd`, `mem`, `fifo`, `sram`, `busy`)

**More worked examples:**

| Before | After | Before | After |
|---|---|---|---|
| `addr_act_wt` | `AddrWt_act` | `addr_wgt_rd` | `AddrRd_wgt` |
| `ena_act` | `Ena_act` | `wea_wgt` | `Wea_wgt` |
| `current_state` | `CurrentState` | `wr_ptr` | `WrPtr` |
| `ff_empty` | `FfEmpty` | `mem_fifo` | `MemFifo` |
| `act_offset` | `Offset_act` | `wgt_offset` | `Offset_wgt` |
| `in_valid_array` | `InValidArray` | `pop_fire` | `PopFire` |
| `result_valid` | `ResultValid` | `bridge_busy` | `BridgeBusy` |

**Scope exclusions (deliberate):**

- `Top_Module`'s 6 board-facing ports — `clk`, `rst_n`, `rx`, `tx`, `busy`, `dbg_state` — are left exactly as-is. They're pinned by exact string in `fpga_bringup/tanknano9k.cst` (`dbg_state` even by per-bit slice), so renaming them would require touching the physical build too, for no behavioral benefit. They're also already atomic tokens, so they don't violate the rule anyway.
- Module/instance names (`U_Bridge`, `S_Core`, `SRAM_wgt`, `PE`, `fifo`, ...) — the rule targets signals, not instance labels.
- `src/No_Use/` — dead code, not part of any build target.

## Where this is enforced today

Every file in `src/` and `sva/`, and all four testbenches in `tb/`, already follow both rules above (parameterization + naming), including the cross-module port lists, the `sva/bind.sv` connections, and the hierarchical `DUT.*` references inside `tb_UART_Bridge.sv`'s watchdog block. Keep new signals consistent with the same two rules.
