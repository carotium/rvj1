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
MUL_OP_DIV = 4
MUL_OP_DIVU = 5
MUL_OP_REM = 6
MUL_OP_REMU = 7

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

    mul_mode = MUL_OP_MUL

    a, b, mul = random_mul_input(mul_mode, 100, 1000000000)
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
            await ClockCycles(dut.clk_i, 4)
        elif (mul_mode == MUL_OP_MULH or mul_mode == MUL_OP_MULHU or mul_mode == MUL_OP_MULHSU):
            await ClockCycles(dut.clk_i, 5)
        mul_out.append(dut.res_o.value)

    assert mul == mul_out, "Output doesn't multiply correctly"

## Remainder
#    a = []
#    b = []
#    div = []
#    rem = []
#    div_out = []
#    rem_out = []
#
#
##    div_mode = MUL_OP_DIV
#    div_mode = MUL_OP_REMU

#    a, b, div, rem = random_div_input(div_mode, 5, 10)
#    a, b, div, rem = random_div_input(div_mode, 5, 4294967295)

#    a.append(9)
#    b.append(3)
#    div.append(3)
#    rem.append(0)

#    # Division by zero
#    a.append(129)
#    b.append(0)
#    if (div_mode == MUL_OP_DIV or div_mode == MUL_OP_REM):
#        div.append(-1)
#        rem.append(129)
#    elif (div_mode == MUL_OP_DIVU or div_mode == MUL_OP_REMU):
#        div.append(2**32-1)
#        rem.append(129)
#    # Overflow
#    if (div_mode == MUL_OP_DIV or div_mode == MUL_OP_REM):
#        a.append(-2**(32-1))
#        b.append(-1)
#        div.append(-2**(32-1))
#        rem.append(0)
#    # Zero divide
#    a.append(0)
#    b.append(52)
#    div.append(0)
#    rem.append(0)
#    # Test case
#    a.append(0x94FAB785)
#    b.append(0xB11E9CA2)
#    div.append(0x0)
#    rem.append(0x94FAB785)

## Remainder
#    for i, div_test in enumerate(rem):
#        dut.op_a_i.value = a[i]
#        dut.op_b_i.value = b[i]
#        dut.sel_i.value = div_mode
#        dut.mul_div_en_i.value = 1
#        await ClockCycles(dut.clk_i, 1)
#        dut.mul_div_en_i.value = 0
#
##        dut.op_a_i.value = 0
##        dut.op_b_i.value = 0
#
#        await ClockCycles(dut.clk_i, 33)
#        rem_out.append(dut.res_o.value)
#        dut.sel_i.value = MUL_OP_MUL
#        await RisingEdge(dut.clk_i)
#
#    assert rem == rem_out, "Output doesn't calculate remainder properly!"

## Division
#    for i, div_test in enumerate(div):
#        dut.op_a_i.value = a[i]
#        dut.op_b_i.value = b[i]
#        dut.sel_i.value = div_mode
#        dut.mul_div_en_i.value = 1
#        await ClockCycles(dut.clk_i, 1)
#        dut.mul_div_en_i.value = 0
#
##        dut.op_a_i.value = 0
##        dut.op_b_i.value = 0
#
#        await ClockCycles(dut.clk_i, 33)
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

def random_div_input(div_mode, num_of_samples, set_range):
    a = []
    b = []
    div = []
    rem = []
    for i in range(num_of_samples):
        if (div_mode == MUL_OP_DIV or div_mode == MUL_OP_REM):
            a.append(randint(-set_range, set_range))
            b.append(randint(-set_range, set_range))
        else:
            a.append(randint(0, set_range))
            b.append(randint(0, set_range))
        if (b[i] == 0):
            if (div_mode == MUL_OP_DIV or div_mode == MUL_OP_REM):
                div.append(-1)
                rem.append(a[i])
            elif (div_mode == MUL_OP_DIVU or div_mode == MUL_OP_REMU):
                div.append(2**32-1)
                rem.append(a[i])
        else:
            div.append(int(a[i] / b[i]))
            if (a[i] != 0):
                rem.append(int((abs(a[i]) % abs(b[i])) * a[i] / abs(a[i])))
            else:
                rem.append(0)
    return a, b, div, rem

def test_add_runner(mul_test_fixture):
    mul_test_fixture.test(
        toplevel=mul_test_fixture.toplevel,
        test_module="test_mul_div",
    )
