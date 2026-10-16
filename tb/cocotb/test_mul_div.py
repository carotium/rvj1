import os
import tempfile
import datetime
import pytest
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock
import cocotb
from random import randint

TIMEOUT_CLOCKS = 1000

MUL_OP_MUL    = 0
MUL_OP_MULH   = 1
MUL_OP_MULHSU = 2
MUL_OP_MULHU  = 3

@cocotb.test()
async def run_mul_div(dut):
    # Start clock
    clock = Clock(dut.clk_i, 10, unit="us")
    clock.start(start_high=False)

    # Reset circuit
    dut.rstn_i.value = 0
    await ClockCycles(dut.clk_i, 2)
    dut.rstn_i.value = 1
# Multiplication
    a = []
    b = []
    mul = []
    mul_out = []


    mul_mode = MUL_OP_MULHU

    a, b, mul = random_mul_input(mul_mode, 10000, 10000000)
#    a = [-5]
#    b = [25]
#    mul = [-1]
#    import pdb; pdb.set_trace()

    for i, mul_test in enumerate(mul):
        dut.op_a_i.value = a[i]
        dut.op_b_i.value = b[i]
        dut.sel_i.value = mul_mode
        dut.mul_div_en_i.value = 1
        await ClockCycles(dut.clk_i, 1)
        dut.mul_div_en_i.value = 0
        if (mul_mode == MUL_OP_MUL):
            await ClockCycles(dut.clk_i, 5)
        elif (mul_mode == MUL_OP_MULH or mul_mode == MUL_OP_MULHU or mul_mode == MUL_OP_MULHSU):
            await ClockCycles(dut.clk_i, 6)
        mul_out.append(dut.res_o.value)
        dut.mul_div_en_i.value = 0
        dut.sel_i.value = MUL_OP_MULH
        await RisingEdge(dut.clk_i)

    assert mul == mul_out, "Output doesn't multiply correctly"
## Division
#    a = []
#    b = []
#    div = []
#    rem = []
#    div_out = []
#    rem_out = []
#
#    MUL_OP_DIV = 4
#    MUL_OP_MUL = 0
#    MUL_OP_REM = 6
#
##    a, b, div, rem = random_div_input(100, 10000)
#
#    # Division by zero
#    a.append(129)
#    b.append(0)
#    div.append(-1)
#    rem.append(129)
#    # Overflow
#    a.append(-2**(32-1))
#    b.append(-1)
#    div.append(-2**(32-1))
#    rem.append(0)
#    # Zero divide
#    a.append(0)
#    b.append(52)
#    div.append(0)
#    rem.append(52)
#
#    for i, div_test in enumerate(div):
#        dut.op_a_i.value = a[i]
#        dut.op_b_i.value = b[i]
#        dut.sel_i.value = MUL_OP_DIV
#        dut.mul_div_en_i.value = 1
#        await ClockCycles(dut.clk_i, 1)
#        dut.mul_div_en_i.value = 0
#
#        dut.op_a_i.value = 0
#        dut.op_b_i.value = 0
#
#        await ClockCycles(dut.clk_i, 34)
#        await RisingEdge(dut.clk_i)
#        div_out.append(dut.res_o.value)
#        dut.sel_i.value = MUL_OP_MUL
#        await RisingEdge(dut.clk_i)
#        
#    assert div == div_out, "Output doesn't divide properly!"

def random_mul_input(mul_mode, num_of_samples, set_range):
    a = []
    b = []
    mul = []
    for i in range(num_of_samples):
        a.append(randint(-set_range, set_range))
        b.append(randint(-set_range, set_range))
        if(mul_mode == MUL_OP_MUL):
            mul.append((int(a[i] * b[i])) & 0xFFFFFFFF)
        elif(mul_mode == MUL_OP_MULH or mul_mode == MUL_OP_MULHU or mul_mode == MUL_OP_MULHSU):
            mul.append((int(a[i] * b[i]) & 0xFFFFFFFF00000000) >> 32)
    return a, b, mul

def random_div_input(num_of_samples, set_range):
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
