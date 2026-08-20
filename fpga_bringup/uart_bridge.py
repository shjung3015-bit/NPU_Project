"""Host-side helper for UART_Bridge's register-map protocol.

Requires pyserial:  pip install pyserial
"""

import time
import serial

PORT = "COM6"
BAUD = 115200

CMD_WRITE = 0x00
CMD_READ = 0x01

ADDR_CONTROL = 0x00        # {run, load_wgt, pop_ena}
ADDR_SRAM_EN = 0x01        # {ena_act, wea_act, ena_wgt, wea_wgt}
ADDR_ADDR_ACT_WT = 0x02
ADDR_ADDR_WGT_WT = 0x03
ADDR_BASE_ADDR_ACT = 0x04
ADDR_BASE_ADDR_WGT = 0x05
ADDR_NUM_ACT = 0x06
ADDR_DIN_ACT = 0x07
ADDR_DIN_WGT = 0x08
ADDR_RESULT = 0x09

RESULT_LEN = 17


class UartBridge:
    def __init__(self, port=PORT, baud=BAUD, timeout=1):
        self.ser = serial.Serial(port, baud, bytesize=8, parity='N', stopbits=1, timeout=timeout)

    def close(self):
        self.ser.close()

    def _write_paced(self, data: bytes, gap=0.02):
        """Write one byte at a time with a small gap, mimicking manual
        keypresses -- used to test whether the bridge only reacts when
        bytes arrive spaced out rather than back-to-back."""
        for b in data:
            self.ser.write(bytes([b]))
            time.sleep(gap)

    def write_reg(self, addr, data: bytes):
        self._write_paced(bytes([CMD_WRITE, addr]) + data)

    def write_16(self, addr, value):
        self.write_reg(addr, (value & 0xFFFF).to_bytes(2, byteorder='big'))

    def write_32(self, addr, value):
        self.write_reg(addr, (value & 0xFFFFFFFF).to_bytes(4, byteorder='big'))

    def read_reg(self, addr, length):
        self._write_paced(bytes([CMD_READ, addr]))
        resp = self.ser.read(length)
        if len(resp) != length:
            raise TimeoutError(f"expected {length} bytes back, got {len(resp)}")
        return resp

    def read_result(self):
        resp = self.read_reg(ADDR_RESULT, RESULT_LEN)
        result_valid = resp[0] & 1
        results = [
            int.from_bytes(resp[1 + i * 4: 5 + i * 4], byteorder='big', signed=True)
            for i in range(4)
        ]
        return result_valid, results


def run_identity_test(bridge: UartBridge):
    """Loads a 4x4 identity weight matrix and activation [1,2,3,4], runs the
    array, and reads the result back -- mirrors tb_System.sv, so the
    expected output is just the activation vector unchanged."""

    bridge.write_reg(ADDR_SRAM_EN, bytes([0b0011]))  # ena_wgt=wea_wgt=1
    weight_rows = [
        (0, 0x00000001),  # row0 = [1,0,0,0]
        (1, 0x00000100),  # row1 = [0,1,0,0]
        (2, 0x00010000),  # row2 = [0,0,1,0]
        (3, 0x01000000),  # row3 = [0,0,0,1]
    ]
    for row_addr, word in weight_rows:
        bridge.write_16(ADDR_ADDR_WGT_WT, row_addr)
        bridge.write_32(ADDR_DIN_WGT, word)

    bridge.write_reg(ADDR_SRAM_EN, bytes([0b1100]))  # ena_act=wea_act=1
    bridge.write_16(ADDR_ADDR_ACT_WT, 0)
    bridge.write_32(ADDR_DIN_ACT, 0x04030201)  # A = [1,2,3,4]

    bridge.write_reg(ADDR_SRAM_EN, bytes([0x00]))
    bridge.write_16(ADDR_NUM_ACT, 1)

    bridge.write_reg(ADDR_CONTROL, bytes([0b010]))  # load_wgt
    time.sleep(0.01)

    bridge.write_reg(ADDR_CONTROL, bytes([0b100]))  # run
    time.sleep(0.01)

    bridge.write_reg(ADDR_CONTROL, bytes([0b001]))  # pop_ena
    time.sleep(0.01)

    valid, results = bridge.read_result()
    print(f"result_valid={valid} results={results}")
    return results


def _pack4(v0, v1, v2, v3):
    """Pack four int8 values into a 32-bit word matching the SRAM layout
    used throughout this protocol: index0 (LSB byte) = element 0, index3
    (MSB byte) = element 3 -- see run_identity_test's weight_rows comments."""
    return ((v3 & 0xFF) << 24) | ((v2 & 0xFF) << 16) | ((v1 & 0xFF) << 8) | (v0 & 0xFF)


def run_streaming_test(bridge: UartBridge, activations):
    """Loads a 4x4 identity weight matrix (same as run_identity_test), then
    streams multiple activation vectors back-to-back in a single `run`
    pulse -- exercises Controller's STREAM state, the credit-based
    inject_ena flow control, and FIFO_All's per-column join logic, instead
    of the one-shot single-vector path.

    activations: list of 4-tuples, e.g. [(1,2,3,4), (5,6,7,8), ...]
    """

    # -- weight: same identity matrix as run_identity_test --
    bridge.write_reg(ADDR_SRAM_EN, bytes([0b0011]))  # ena_wgt=wea_wgt=1
    weight_rows = [
        (0, 0x00000001),
        (1, 0x00000100),
        (2, 0x00010000),
        (3, 0x01000000),
    ]
    for row_addr, word in weight_rows:
        bridge.write_16(ADDR_ADDR_WGT_WT, row_addr)
        bridge.write_32(ADDR_DIN_WGT, word)

    # -- activations: load N vectors into consecutive SRAM addresses --
    bridge.write_reg(ADDR_SRAM_EN, bytes([0b1100]))  # ena_act=wea_act=1
    for i, vec in enumerate(activations):
        bridge.write_16(ADDR_ADDR_ACT_WT, i)
        bridge.write_32(ADDR_DIN_ACT, _pack4(*vec))

    bridge.write_reg(ADDR_SRAM_EN, bytes([0x00]))
    bridge.write_16(ADDR_NUM_ACT, len(activations))

    bridge.write_reg(ADDR_CONTROL, bytes([0b010]))  # load_wgt (pulse)
    time.sleep(0.01)

    bridge.write_reg(ADDR_CONTROL, bytes([0b100]))  # run (pulse) -- STREAM
    time.sleep(0.02)                                 # injects all N on its own

    all_results = []
    for i, expected in enumerate(activations):
        bridge.write_reg(ADDR_CONTROL, bytes([0b001]))  # pop_ena high
        time.sleep(0.005)
        valid, results = bridge.read_result()
        bridge.write_reg(ADDR_CONTROL, bytes([0b000]))  # pop_ena low again
        # so we don't silently auto-drain the next result before we ask for it
        status = "OK" if results == list(expected) else "MISMATCH"
        print(f"vector {i}: expected={list(expected)} got={results} valid={valid} [{status}]")
        all_results.append(results)

    return all_results


def compute_expected(weight, activation):
    """weight: 4x4 list/tuple of rows (weight[i][j]). activation: 4-tuple.
    Mirrors the hardware's dataflow: row i's activation flows right and
    gets multiplied by that row's weight at each column it passes, so
    out[j] = sum_i activation[i] * weight[i][j]."""
    return [
        sum(activation[i] * weight[i][j] for i in range(4))
        for j in range(4)
    ]


def run_matmul_test(bridge: UartBridge, weight, activations):
    """General (non-identity) weight-stationary matmul test. weight is a
    4x4 sequence of int8 rows; activations is a list of 4-tuples. Computes
    the expected result in Python (golden model, same idea as
    tb_System.sv's self-checking testbench) and compares it against what
    comes back from the real board."""

    bridge.write_reg(ADDR_SRAM_EN, bytes([0b0011]))  # ena_wgt=wea_wgt=1
    for row_addr, row in enumerate(weight):
        bridge.write_16(ADDR_ADDR_WGT_WT, row_addr)
        bridge.write_32(ADDR_DIN_WGT, _pack4(*row))

    bridge.write_reg(ADDR_SRAM_EN, bytes([0b1100]))  # ena_act=wea_act=1
    for i, vec in enumerate(activations):
        bridge.write_16(ADDR_ADDR_ACT_WT, i)
        bridge.write_32(ADDR_DIN_ACT, _pack4(*vec))

    bridge.write_reg(ADDR_SRAM_EN, bytes([0x00]))
    bridge.write_16(ADDR_NUM_ACT, len(activations))

    bridge.write_reg(ADDR_CONTROL, bytes([0b010]))  # load_wgt (pulse)
    time.sleep(0.01)

    bridge.write_reg(ADDR_CONTROL, bytes([0b100]))  # run (pulse)
    time.sleep(0.02)

    all_pass = True
    for i, vec in enumerate(activations):
        expected = compute_expected(weight, vec)
        bridge.write_reg(ADDR_CONTROL, bytes([0b001]))  # pop_ena high
        time.sleep(0.005)
        valid, results = bridge.read_result()
        bridge.write_reg(ADDR_CONTROL, bytes([0b000]))  # pop_ena low
        status = "OK" if results == expected else "MISMATCH"
        if status == "MISMATCH":
            all_pass = False
        print(f"vector {i}: act={vec} expected={expected} got={results} valid={valid} [{status}]")

    return all_pass


if __name__ == "__main__":
    bridge = UartBridge()
    try:
        print("-- quick sanity read of result register --")
        valid, results = bridge.read_result()
        print(f"result_valid={valid} results={results}")

        print("-- identity-matrix test --")
        results = run_identity_test(bridge)
        expected = [1, 2, 3, 4]
        if results == expected:
            print("PASS - results match expected", expected)
        else:
            print("FAIL - got", results, "expected", expected)

        print("-- streaming test (4 activations back-to-back) --")
        vectors = [(1, 2, 3, 4), (5, 6, 7, 8), (9, 10, 11, 12), (13, 14, 15, 16)]
        streamed = run_streaming_test(bridge, vectors)
        if streamed == [list(v) for v in vectors]:
            print("PASS - all vectors matched, in order")
        else:
            print("FAIL - see mismatches above")

        print("-- real matmul test (non-identity weight, negative values) --")
        weight = [
            [ 1,  2, -1,  0],
            [ 0, -1,  2,  1],
            [ 3,  0,  1, -2],
            [-1,  1,  0,  2],
        ]
        act_vectors = [(1, -2, 3, 4)]
        if run_matmul_test(bridge, weight, act_vectors):
            print("PASS - matmul result matches golden model")
        else:
            print("FAIL - matmul result does not match golden model")
    finally:
        bridge.close()
