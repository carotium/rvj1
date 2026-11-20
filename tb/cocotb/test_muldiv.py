import os
import random

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

XLEN = 32
MASK = (1 << XLEN) - 1

OPS = {
    "MUL" : 0,
    "MULH" : 1,
    "MULHSU" : 2,
    "MULHU" : 3,
    "DIV" : 4,
    "DIVU" : 5,
    "REM" : 6,
    "REMU" : 7,
}

LATENCY = {
    "MUL" : 4,
    "MULH" : 5,
    "MULHSU" : 5,
    "MULHU" : 5,
    "DIV" : 33,
    "DIVU" : 33,
    "REM" : 33,
    "REMU" : 33,
}

EDGE_CASES = [
    0x0000_0000,
    0x0000_0001,
    0x0000_0002,
    0x0000_7FFF,
    0x0000_8000,
    0x0000_FFFF,
    0x0001_0000,
    0x7FFF_FFFF,
    0x8000_0000,
    0x8000_0001,
    0xFFFF_0000,
    0xFFFF_FFFF,
    0x1234_5678,
]

def to_signed(x: int) -> int:
    x &= MASK
    return x - (1 << XLEN) if x >> (XLEN - 1) else x

def ref_model(op: str, a: int, b: int) -> int:
    a &= MASK
    b &= MASK
    sa, sb = to_signed(a), to_signed(b)

    if op == "MUL":
        return (a * b) & MASK
    if op == "MULH":
        return ((sa * sb) >> XLEN) & MASK
    if op == "MULHSU":
        return ((sa * b) >> XLEN) & MASK
    if op == "MULHU":
        return ((a * b) >> XLEN) & MASK

    if op in ("DIV", "REM"):
        if b == 0:
            return MASK if op == "DIV" else a
        if sa == -(2 ** 31) and sb == -1:
            return a if op == "DIV" else 0
        q = abs(sa) // abs(sb)
        r = abs(sa) % abs(sb)
        q = -q if (sa < 0) != (sb < 0) else q
        r = -r if sa < 0 else r
        return (q if op == "DIV" else r) & MASK

    if op == "DIVU":
        return MASK if b == 0 else a // b
    if op == "REMU":
        return a if b == 0 else a % b

    raise ValueError(op)

async def start_and_reset(dut):
    """Run clock and restart"""
    clock = Clock(dut.clk_i, 10, unit="us")
    clock.start(start_high=False)

    dut.mul_div_en_i.value = 0
    dut.op_a_i.value = 0
    dut.op_b_i.value = 0
    dut.sel_i.value = OPS["MUL"]
    dut.rstn_i.value = 0
    await ClockCycles(dut.clk_i, 2)
    dut.rstn_i.value = 1
    await RisingEdge(dut.clk_i)

async def run_op(dut, op: str, a: int, b: int) -> int:
    """
    Run one operation like a decoder would:
        - set operands and select operation,
        - one clock cycle enable impulse,
        - wait for LATENCY cycles,
        - read result
    """    
    dut.op_a_i.value = a & MASK
    dut.op_b_i.value = b & MASK
    dut.sel_i.value = OPS[op]
    dut.mul_div_en_i.value = 1
    await ClockCycles(dut.clk_i, 1)
    dut.mul_div_en_i.value = 0
    await ClockCycles(dut.clk_i, LATENCY[op])
    return int(dut.res_o.value)

def check(failures: list, op: str, a: int, b: int, got: int):
    exp = ref_model(op, a, b)
    if got != exp:
        failures.append(f"{op:7s} a={a:#010x} b={b:#010x} got={got:#010x} exp={exp:#010x}")

def assert_no_failures(failures: list, total: int):
    if failures:
        shown = "\n ".join(failures[:10])
        raise AssertionError(
            f"{len(failures)}/{total} cases wrong (first 10):\n  {shown}"
        )

@cocotb.test()
async def corner_cases(dut):
    await start_and_reset(dut)
    failures, total = [], 0
    for op in OPS:
        for a in EDGE_CASES:
            for b in EDGE_CASES:
                got = await run_op(dut, op, a, b)
                check(failures, op, a, b, got)
                total += 1
    assert_no_failures(failures, total)


@cocotb.test()
async def spec_special_cases(dut):
    await start_and_reset(dut)
    cases = [
        # (op,    a,         b,    expected)
        ("DIV", 129, 0, MASK),
        ("DIVU", 129, 0, MASK),
        ("REM", 129, 0, 129),
        ("REMU", 129, 0, 129),
        ("DIV", 0x8000_0000, MASK, 0x8000_0000),
        ("REM", 0x8000_0000, MASK, 0),
        ("DIV", (-7) & MASK, 2, (-3) & MASK),
        ("REM", (-7) & MASK, 2, (-1) & MASK),
        ("REM", 7, (-2) & MASK, 1),
        ("MULH", MASK, MASK, 0x0000_0000),
        ("MULHSU", MASK, MASK, MASK),
    ]            
    failures = []
    for op, a, b, exp in cases:
        assert ref_model(op, a, b) == exp, f"Error in reference model: {op} {a:#x} {b:#x}"
        got = await run_op(dut, op, a, b)
        check(failures, op, a, b, got)
    assert_no_failures(failures, len(cases))

@cocotb.test()
async def random_ops(dut):
    seed = int(os.getenv("RANDOM SEED", random.randrange(1 << 30)))
    dut._log.info(f"RANDOM SEED={seed}")
    rng = random.Random(seed)

    await start_and_reset(dut)
    failures, total = [], 0
    for op in OPS:
        for _ in range(300):
            a = rng.choice(EDGE_CASES) if rng.random() < 0.2 else rng.getrandbits(XLEN)
            b = rng.choice(EDGE_CASES) if rng.random() < 0.2 else rng.getrandbits(XLEN)
            got = await run_op(dut, op, a, b)
            check(failures, op, a, b, got)
            total += 1
    assert_no_failures(failures, total)

@cocotb.test()
async def mixed_sequence(dut):
    rng = random.Random(1234)
    await start_and_reset(dut)
    failures, total = [], 0
    ops = list(OPS)
    for _ in range(400):
        op = rng.choice(ops)
        a, b = rng.getrandbits(XLEN), rng.getrandbits(XLEN)
        got = await run_op(dut, op, a, b)
        check(failures, op, a, b, got)
        total += 1
    assert_no_failures(failures, total)

@cocotb.test()
async def reset_during_division(dut):
    await start_and_reset(dut)
    dut.op_a_i.value = 0xDEAD_BEEF
    dut.op_b_i.value = 0x0000_0007
    dut.sel_i.value = OPS["DIVU"]
    dut.mul_div_en_i.value = 1
    await ClockCycles(dut.clk_i, 1)
    dut.mul_div_en_i.value = 0
    await ClockCycles(dut.clk_i, 10)

    dut.rstn_i.value = 0
    await ClockCycles(dut.clk_i, 2)
    dut.rstn_i.value = 1
    await RisingEdge(dut.clk_i)

    failures = []
    for op, a, b in [("MUL", 6, 7), ("DIVU", 100, 7), ("REMU", 100, 7)]:
        got = await run_op(dut, op, a, b)
        check(failures, op, a, b, got)
    assert_no_failures(failures, 3)

def test_mul_div_runner(mul_test_fixture):
    mul_test_fixture.test(
        toplevel=mul_test_fixture.toplevel,
        test_module="test_muldiv",
    )