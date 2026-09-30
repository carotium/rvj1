import os
import tempfile
import datetime
import pytest
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock
import cocotb
from random import randint

TIMEOUT_CLOCKS = 1000

@cocotb.test()
async def run_mul_div(dut):
    # Start clock
    clock = Clock(dut.clk_i, 10, unit="us")
    clock.start(start_high=False)

    # Reset circuit
    dut.rstn_i.value = 0
    await ClockCycles(dut.clk_i, 2)
    dut.rstn_i.value = 1

    a = []
    b = []
    div = []
    rem = []
    div_out = []
    rem_out = []

    MUL_OP_DIV = 4
    MUL_OP_MUL = 0
    MUL_OP_REM = 6

    a, b, div, rem = random_input(100, 10000)

    # Division by zero
    a.append(129)
    b.append(0)
    div.append(-1)
    rem.append(129)
    # Overflow
    a.append(-2**(32-1))
    b.append(-1)
    div.append(-2**(32-1))
    rem.append(0)

    for i, div_test in enumerate(div):
        dut.op_a_i.value = a[i]
        dut.op_b_i.value = b[i]
        dut.sel_i.value = MUL_OP_DIV
        dut.mul_div_en_i.value = 1
        await ClockCycles(dut.clk_i, 1)
        dut.mul_div_en_i.value = 0

        dut.op_a_i.value = 0
        dut.op_b_i.value = 0

        await ClockCycles(dut.clk_i, 34)
        await RisingEdge(dut.clk_i)
        div_out.append(dut.res_o.value)
        dut.sel_i.value = MUL_OP_MUL
        await RisingEdge(dut.clk_i)
        
    assert div == div_out, "Output doesn't calculate properly!"

#    for i, div in enumerate(rem):
#        dut.op_a_i.value = a[i]
#        dut.op_b_i.value = b[i]
#        dut.sel_i.value = MUL_OP_REM
#        dut.mul_div_en_i.value = 1
#        await ClockCycles(dut.clk_i, 1)
#        dut.mul_div_en_i.value = 0
#
#        dut.op_a_i.value = 0
#        dut.op_b_i.value = 0
#
#        await ClockCycles(dut.clk_i, 34)
#        await RisingEdge(dut.clk_i)
#        rem_out.append(dut.res_o.value)
#        dut.sel_i.value = MUL_OP_MUL
#        await RisingEdge(dut.clk_i)
#        
#    assert rem == rem_out, "Output doesn't calculate properly!"

def random_input(num_of_samples, set_range):
    a = []
    b = []
    div = []
    rem = []
    for i in range(num_of_samples):
        a.append(randint(-set_range, set_range))
        b.append(randint(-set_range, set_range))
        if (b[i] == 0):
            div.append(-1)
            rem.append(a[i])
        else:
            div.append(int(a[i] / b[i]))
            rem.append(a[i] % b[i])
    return a, b, div, rem


def test_add_runner(mul_test_fixture):
    mul_test_fixture.test(
        toplevel=mul_test_fixture.toplevel,
        test_module="test_mul_div",
    )
