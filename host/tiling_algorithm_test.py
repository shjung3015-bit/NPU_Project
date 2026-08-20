"""
Stage 1 - pure-Python validation of the GEMM tiling/assembly math for the
4x4 weight-stationary systolic array. No hardware, no pyserial, no
dependency on host/uart_test.py.

The physical array only computes a <=4x4 (K x N) sub-tile per pass. To
handle a weight matrix larger than 4x4 we split it into
ceil(K/4) x ceil(N/4) sub-tiles, and reassemble the per-tile results:
  - sub-tiles that share the same N-tile (differ only in K-tile) are SUMMED
    (K is the reduction dimension)
  - sub-tiles from different N-tiles are CONCATENATED side by side

This script stands in for "the hardware" by computing each sub-tile result
directly with numpy (activation_slice @ weight_subblock), so only the
tiling/assembly bookkeeping itself is under test here.
"""

import math
import numpy as np

ARRAY_SIZE = 4   # physical systolic array is ARRAY_SIZE x ARRAY_SIZE
K = 8            # weight rows     (reduction dimension)
N = 12           # weight columns  (output width)


def gen_test_data(rng):
    """Random int8 weight/activation matrices, and a random M (activation
    row count) between 1 and 10 inclusive."""
    M = int(rng.integers(1, 11))
    weight = rng.integers(-128, 128, size=(K, N), dtype=np.int64)
    activation = rng.integers(-128, 128, size=(M, K), dtype=np.int64)
    return M, weight, activation


def compute_golden(activation, weight):
    """int64-accumulated matmul, matching the hardware's 32-bit signed
    psum width (well within int64 range for these sizes)."""
    return activation @ weight


def compute_tiled(activation, weight):
    """Split into ceil(K/4) x ceil(N/4) sub-tiles, compute each sub-tile's
    raw result independently (standing in for a real hardware pass), then
    do a separate assembly pass: sum across K-tiles within an N-tile, then
    concatenate across N-tiles."""
    k_tiles = math.ceil(K / ARRAY_SIZE)
    n_tiles = math.ceil(N / ARRAY_SIZE)

    # --- pass 1: collect every raw per-tile result first (no assembling
    # as we go) ---
    raw = {}
    for n_tile in range(n_tiles):
        n0 = n_tile * ARRAY_SIZE
        n1 = min(n0 + ARRAY_SIZE, N)
        for k_tile in range(k_tiles):
            k0 = k_tile * ARRAY_SIZE
            k1 = min(k0 + ARRAY_SIZE, K)

            act_slice = activation[:, k0:k1]      # M x ksub
            wgt_sub = weight[k0:k1, n0:n1]        # ksub x nsub
            raw[(k_tile, n_tile)] = act_slice @ wgt_sub  # "what hw returns"

    # --- pass 2: assemble (sum over K-tiles, concat over N-tiles) ---
    n_tile_columns = []
    for n_tile in range(n_tiles):
        acc = None
        for k_tile in range(k_tiles):
            tile = raw[(k_tile, n_tile)]
            acc = tile if acc is None else acc + tile
        n_tile_columns.append(acc)

    return np.concatenate(n_tile_columns, axis=1)


def run_trial(seed):
    rng = np.random.default_rng(seed)
    M, weight, activation = gen_test_data(rng)

    golden = compute_golden(activation, weight)
    assembled = compute_tiled(activation, weight)

    mismatches = np.argwhere(golden != assembled)
    return M, golden, assembled, mismatches


def main():
    num_trials = 20
    all_passed = True

    print(f"Stage 1: tiling/assembly algorithm check "
          f"(K={K}, N={N}, ARRAY_SIZE={ARRAY_SIZE}, {num_trials} trials)\n")

    for seed in range(num_trials):
        M, golden, assembled, mismatches = run_trial(seed)

        if mismatches.size == 0:
            print(f"[seed {seed:3d}] M={M:2d}  PASS")
        else:
            all_passed = False
            print(f"[seed {seed:3d}] M={M:2d}  FAIL "
                  f"({len(mismatches)} mismatching element(s))")
            for row, col in mismatches:
                print(f"    (row={row}, col={col})  "
                      f"got={assembled[row, col]}  exp={golden[row, col]}")

    print()
    if all_passed:
        print(f"ALL {num_trials} TRIALS PASSED")
    else:
        print("SOME TRIALS FAILED (see above)")

    return 0 if all_passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
