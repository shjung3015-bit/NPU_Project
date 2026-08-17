"""Host-side helper for UART_Bridge's register-map protocol.

Requires pyserial:  pip install pyserial
"""

import time
import serial

PORT = "COM8"
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

    def write_reg(self, addr, data: bytes):
        self.ser.write(bytes([CMD_WRITE, addr]) + data)

    def write_16(self, addr, value):
        self.write_reg(addr, (value & 0xFFFF).to_bytes(2, byteorder='big'))

    def write_32(self, addr, value):
        self.write_reg(addr, (value & 0xFFFFFFFF).to_bytes(4, byteorder='big'))

    def read_reg(self, addr, length):
        self.ser.write(bytes([CMD_READ, addr]))
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
    finally:
        bridge.close()
