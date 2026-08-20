# Prompt for Claude Code — GEMM tiling validation, staged

I want to validate a GEMM-tiling scheme for our 4x4 weight-stationary systolic
array in three separate, sequential stages. Do NOT skip ahead to a later stage
until the previous one passes — each stage exists specifically to isolate a
different possible source of bugs (algorithm vs. RTL vs. real hardware/UART).

## Background

The physical array is 4x4 (K<=4, N<=4 per pass). To handle a weight matrix
larger than 4x4, we split it into ceil(K/4) x ceil(N/4) sub-tiles of at most
4x4 each, run each sub-tile through the array, and reassemble:
- Sub-tile results that share the same N-tile (i.e. differ only in which
  K-tile they came from) get SUMMED together (K is the reduction dimension).
- Sub-tile results from different N-tiles get CONCATENATED side by side (N-tiles
  are independent, non-overlapping output columns).
- The M dimension (number of activation rows / `num_act`) is never tiled — it
  streams freely regardless of size, that's already handled by the existing
  hardware.

Traversal order: outer loop over N-tiles, inner loop over K-tiles (finish all
K-tiles for the current N-tile before moving to the next N-tile). This is the
same order we already reasoned through by hand.

Test data for all three stages (same random data used throughout, so results
are directly comparable across stages):
- Weight matrix: fixed shape K=8 (rows), N=12 (columns), random int8 values.
  Both 8 and 12 are already multiples of 4, so no zero-padding logic is needed
  for this test yet — but please write the tiling math generically using
  ceil(K/4) and ceil(N/4) rather than hardcoding 2 and 3 tiles, so it's easy to
  extend to non-multiple-of-4 sizes later.
- Activation: a random number M (e.g. randomly chosen between 1 and 10 each
  run) of vectors, each of length K=8, random int8 values.
- Golden reference: compute `activation_matrix @ weight_matrix` in numpy using
  int32/int64 accumulation (not float), matching the hardware's 32-bit signed
  psum width.

---

## Stage 1 — host/tiling_algorithm_test.py (pure Python, no hardware at all)

Purpose: verify ONLY the tiling/assembly math is correct. This must have zero
dependency on pyserial, zero dependency on any hardware, and zero dependency on
host/uart_test.py.

- Generate the weight/activation test data as described above.
- Instead of querying real hardware for each (K-tile, N-tile) sub-result,
  compute it directly in numpy as `activation_slice @ weight_subblock` — this
  stands in for "what the hardware would have returned" for that tile.
- Collect all raw per-tile results (don't accumulate/assemble as you go —
  store them all first, matching the "compute everything first, assemble
  after" approach we settled on).
- Do a separate assembly pass: sum across K-tiles within each N-tile, then
  concatenate across N-tiles, to produce the final M x 12 result.
- Compare element-by-element against the golden numpy reference. Print
  PASS/FAIL; on failure print exactly which (row, col) mismatched and both
  values.
- Run this multiple times (different random seeds) in a loop to build
  confidence the algorithm generalizes, not just one lucky case.

Stop here and report the result before moving to Stage 2.

## Stage 2 — tb/tb_Tiling.sv (Verilator testbench, no real hardware)

Purpose: verify the actual RTL (Controller.sv / UART_Bridge.sv / SRAM
addressing) correctly supports being reconfigured with a new weight tile
repeatedly, back-to-back, which has never been exercised before (previous
testbenches only loaded weights once).

- Reuse the bit-banged host-side UART model from tb/tb_UART_Bridge.sv (send_write1/
  send_write2/send_write4/send_read helpers) — read that file first to match its
  style and confirm the exact register semantics from src/UART_Bridge.sv rather
  than assuming.
- Drive the same overall sequence as Stage 1's algorithm, but this time actually
  issue the real WRITE_REG/READ_REG byte sequences to stage weight/activation data,
  trigger load_wgt and run for each of the 6 (K-tile, N-tile) combinations, and
  read back each tile's real result from the DUT.
- Assemble the results the same way as Stage 1 (sum within N-tile across K-tiles,
  concatenate across N-tiles).
- Compare against the same golden numpy computation (you can hardcode the same
  random seed/data used in Stage 1, or generate fresh SystemVerilog-side random
  stimuli plus an equivalent SV-computed golden check — your call, whichever is
  cleaner to implement).
- Run via Verilator (`verilator --binary --assert --timing` per how test_sva is
  invoked elsewhere in this project). Report PASS/FAIL clearly.

Stop here and report the result before moving to Stage 3.

## Stage 3 — host/tiling_hw_test.py (real FPGA over UART)

Purpose: confirm real hardware behaves the same as the Verilator simulation for
this sequence, i.e. only real-electrical/timing/UART issues remain as possible
failure sources at this point.

- Reuse the `UartBridge` class from host/uart_test.py as-is (write1/write2/
  write4/read_reg/read_status) — don't reimplement the low-level protocol.
- Run the exact same sequence as Stage 2, but over the real serial port against
  the actual flashed board.
- Compare against the same golden numpy computation.
- Print progress as it goes (which tile is being loaded/computed) since this
  will be slow over real UART. Ask me for the COM port rather than guessing one.

Only attempt Stage 3 after confirming Stage 1 and Stage 2 both pass.
