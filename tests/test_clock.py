"""Execute the assembled DOS EXE in an x86 emulator with controlled RTC ports.

The MZ loader applies relocations. Only CMOS I/O and DOS character/string output
are stubbed; conversion, branching and printing execute from test.asm's binary.
"""
import os
from pathlib import Path
import struct
import unittest

from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INSN, UC_HOOK_INTR
from unicorn.x86_const import (
    UC_X86_INS_IN, UC_X86_INS_OUT, UC_X86_REG_AX, UC_X86_REG_AL,
    UC_X86_REG_CS, UC_X86_REG_IP, UC_X86_REG_DS, UC_X86_REG_ES,
    UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_DX,
)

EXE = Path(os.environ.get('CLOCK_EXE', Path(__file__).resolve().parents[1] / 'build/clock.exe'))
WEEKDAYS = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')
CASES_EXECUTED = 0


def run_clock(registers):
    global CASES_EXECUTED
    data = EXE.read_bytes()
    header = struct.unpack_from('<14H', data)
    if header[0] != 0x5A4D:
        raise AssertionError('expected a DOS MZ executable')
    size = (header[2] - 1) * 512 + (header[1] or 512)
    image = bytearray(data[header[4] * 16:size])
    load_segment = 0x1000
    for index in range(header[3]):
        offset, segment = struct.unpack_from('<HH', data, header[12] + 4 * index)
        address = segment * 16 + offset
        value = struct.unpack_from('<H', image, address)[0]
        struct.pack_into('<H', image, address, (value + load_segment) & 0xFFFF)

    cpu = Uc(UC_ARCH_X86, UC_MODE_16)
    cpu.mem_map(0, 1024 * 1024)
    cpu.mem_write(load_segment * 16, bytes(image))
    cpu.reg_write(UC_X86_REG_CS, load_segment + header[11])
    cpu.reg_write(UC_X86_REG_IP, header[10])
    cpu.reg_write(UC_X86_REG_SS, load_segment + header[7])
    cpu.reg_write(UC_X86_REG_SP, header[8])
    cpu.reg_write(UC_X86_REG_DS, load_segment - 16)
    cpu.reg_write(UC_X86_REG_ES, load_segment - 16)
    selected = None
    output = bytearray()
    exit_code = None

    def out_port(uc, port, size, value, _):
        nonlocal selected
        if (port, size) != (0x70, 1):
            raise AssertionError(f'unexpected OUT {port:x}/{size}')
        selected = value & 0x7F

    def in_port(uc, port, size, _):
        if (port, size) != (0x71, 1) or selected not in registers:
            raise AssertionError(f'unexpected RTC read: port={port:x}, register={selected}')
        return registers[selected]

    def interrupt(uc, number, _):
        nonlocal exit_code
        if number != 0x21:
            raise AssertionError(f'unexpected interrupt {number:x}')
        ax = uc.reg_read(UC_X86_REG_AX)
        function = ax >> 8
        if function == 2:
            value = uc.reg_read(UC_X86_REG_DX) & 0xFF
            output.append(value)
            uc.reg_write(UC_X86_REG_AL, value)
        elif function == 9:
            address = uc.reg_read(UC_X86_REG_DS) * 16 + uc.reg_read(UC_X86_REG_DX)
            for offset in range(200):
                value = uc.mem_read(address + offset, 1)[0]
                if value == ord('$'):
                    break
                output.append(value)
            else:
                raise AssertionError('unterminated DOS output string')
            uc.reg_write(UC_X86_REG_AL, ord('$'))
        elif function == 0x4C:
            exit_code = ax & 0xFF
            uc.emu_stop()
        else:
            raise AssertionError(f'unexpected DOS function {function:x}')

    cpu.hook_add(UC_HOOK_INSN, out_port, None, 1, 0, UC_X86_INS_OUT)
    cpu.hook_add(UC_HOOK_INSN, in_port, None, 1, 0, UC_X86_INS_IN)
    cpu.hook_add(UC_HOOK_INTR, interrupt)
    start = (load_segment + header[11]) * 16 + header[10]
    cpu.emu_start(start, 0xFFFFF, timeout=100_000, count=20_000)
    if exit_code != 0:
        raise AssertionError(f'program failed to exit normally: {exit_code}')
    CASES_EXECUTED += 1
    return output.decode('ascii')


def fixture(mode, hour=21, year=26, month=10, day=12, minute=59, weekday=1):
    def encode(value):
        return value if mode & 4 else ((value // 10) << 4) | value % 10
    encoded_hour = encode(hour if mode & 2 else hour % 12 or 12)
    if not mode & 2 and hour >= 12:
        encoded_hour |= 0x80
    return {0xB: mode, 9: encode(year), 8: encode(month), 7: encode(day),
            4: encoded_hour, 2: encode(minute), 6: weekday}


class ClockRegression(unittest.TestCase):
    def check_output(self, mode, **values):
        fields = dict(year=26, month=10, day=12, hour=21, minute=59, weekday=1)
        fields.update(values)
        expected = (f"{fields['year']:02}-{fields['month']:02}-{fields['day']:02} "
                    f"{fields['hour']:02}:{fields['minute']:02} "
                    f"{WEEKDAYS[fields['weekday'] - 1]}\r\n")
        self.assertEqual(run_clock(fixture(mode, **fields)), expected)

    def test_all_weekdays_in_all_data_and_hour_modes(self):
        for mode in (0, 2, 4, 6):
            for weekday in range(1, 8):
                with self.subTest(mode=mode, weekday=weekday):
                    self.check_output(mode, weekday=weekday)

    def test_every_hour_including_midnight_noon_and_pm(self):
        for mode in (0, 2, 4, 6):
            for hour in range(24):
                with self.subTest(mode=mode, hour=hour):
                    self.check_output(mode, hour=hour)

    def test_every_valid_numeric_field_in_both_data_modes(self):
        for mode in (2, 6):
            for field, values in [('year', range(100)), ('month', range(1, 13)),
                                  ('day', range(1, 32)), ('minute', range(60))]:
                for value in values:
                    with self.subTest(mode=mode, field=field, value=value):
                        self.check_output(mode, **{field: value})

    def test_unrelated_register_b_bits_do_not_change_format(self):
        for mode in (0, 2, 4, 6):
            self.check_output(mode | 0xF9)

    def test_invalid_weekday_is_not_used_as_a_table_index(self):
        for weekday in (0, 8, 255):
            self.assertEqual(run_clock(fixture(2, weekday=weekday)), '26-10-12 21:59 Unknown\r\n')


if __name__ == '__main__':
    result = unittest.main(verbosity=2, exit=False).result
    print(f'Executed {CASES_EXECUTED} RTC fixtures against {EXE.name}')
    raise SystemExit(not result.wasSuccessful())
