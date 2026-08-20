"""
UART host-side test script for the Systolic_Array Top_Module / UART_Bridge.

Protocol (mirrors src/UART_Bridge.sv's register map exactly):
    Write:  [0x00][ADDR][DATA...]
    Read:   [0x01][ADDR]  -> board replies with the register's byte width

Register map (from UART_Bridge.sv's WAIT_ADDR / COMMIT logic):
    0x00  1B   {run, load_wgt, pop_ena}                  (write)
    0x01  1B   {ena_act, wea_act, ena_wgt, wea_wgt}       (write)
    0x02  2B   addr_act_wt                                (write)
    0x03  2B   addr_wgt_wt                                (write)
    0x04  2B   base_addr_act                               (write)
    0x05  2B   base_addr_wgt                               (write)
    0x06  2B   num_act                                     (write)
    0x07  4B   din_act                                     (write)
    0x08  4B   din_wgt                                     (write)
    0x09  17B  {result_valid[0], result[3:0][31:0]}         (read-only)

Install once:  pip install pyserial
"""

import time
import serial
import serial.tools.list_ports

# ---- Configuration ----------------------------------------------------
BAUD_RATE = 115200

# TODO: fill in your actual COM port before running.
# Tang Nano 9K shows up as TWO serial devices - use the HIGHER-numbered
# one (the lower one is the JTAG/debug interface, not UART).
# Run this file once with COM_PORT left as-is to just print the list of
# available ports, then fill this in and re-run.
COM_PORT = "COM5"

WRITE = 0x00
READ = 0x01

# ---- Register map -------------------------------------------------------
REG_CTRL        = 0x00  # {run, load_wgt, pop_ena}
REG_SRAM_CTRL   = 0x01  # {ena_act, wea_act, ena_wgt, wea_wgt}
REG_ADDR_ACT_WT = 0x02
REG_ADDR_WGT_WT = 0x03
REG_BASE_ACT    = 0x04
REG_BASE_WGT    = 0x05
REG_NUM_ACT     = 0x06
REG_DIN_ACT     = 0x07
REG_DIN_WGT     = 0x08
REG_RESULT      = 0x09  # read-only, 17 bytes


def list_available_ports():
    ports = serial.tools.list_ports.comports()
    if not ports:
        print("  (no serial ports found)")
    for p in ports:
        print(f"  {p.device} - {p.description}")


class UartBridge:
    """Thin wrapper mirroring tb_UART_Bridge.sv's send_write1/2/4 / send_read
    helpers, but over a real serial port instead of a bit-banged testbench
    wire."""

    def __init__(self, port, baud=BAUD_RATE, timeout=1.0):
        self.ser = serial.Serial(port, baud, timeout=timeout)
        time.sleep(0.1)  # let the OS/driver settle after opening the port

    def close(self):
        self.ser.close()

    # ---- writes ----
    def write_reg(self, addr, data_bytes):
        """data_bytes: iterable of ints, MSB first, matching the register's
        byte width in the table above."""
        packet = bytes([WRITE, addr]) + bytes(data_bytes)
        self.ser.write(packet)

    def write1(self, addr, value):
        self.write_reg(addr, [value & 0xFF])

    def write2(self, addr, value):
        self.write_reg(addr, [(value >> 8) & 0xFF, value & 0xFF])

    def write4(self, addr, value):
        self.write_reg(addr, [
            (value >> 24) & 0xFF,
            (value >> 16) & 0xFF,
            (value >> 8) & 0xFF,
            value & 0xFF,
        ])

    # ---- reads ----
    def read_reg(self, addr, num_bytes):
        self.ser.write(bytes([READ, addr]))
        resp = self.ser.read(num_bytes)
        if len(resp) != num_bytes:
            raise TimeoutError(
                f"addr 0x{addr:02X}: expected {num_bytes} bytes back, "
                f"got {len(resp)} (board not responding / wrong COM port / "
                f"wrong baud rate?)"
            )
        return resp

    def read_status(self):
        """addr 0x09 -> (result_valid, [result0..result3] as signed ints)"""
        resp = self.read_reg(REG_RESULT, 17)
        result_valid = resp[0] & 0x1
        results = []
        for i in range(4):
            chunk = resp[1 + i * 4: 1 + i * 4 + 4]
            val = int.from_bytes(chunk, byteorder="big", signed=True)
            results.append(val)
        return result_valid, results


if __name__ == "__main__":
    print("Available serial ports:")
    list_available_ports()
    print()

    bridge = UartBridge(COM_PORT)

    # Smallest possible smoke test (matches the priority order we agreed on):
    # write something harmless to REG_CTRL, then read REG_RESULT back and
    # confirm the round trip works at all before touching real weights/data.
    print(f"Writing 0x00 to REG_CTRL (addr 0x{REG_CTRL:02X})...")
    bridge.write1(REG_CTRL, 0x00)
    time.sleep(0.05)

    print(f"Reading REG_RESULT (addr 0x{REG_RESULT:02X})...")
    valid, results = bridge.read_status()
    print(f"result_valid = {valid}")
    print(f"results      = {results}")

    bridge.close()
