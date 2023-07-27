import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles


outputs = [ 0x0099, 0xff99, 0xff99, 0x5599, 0x0077, 0x0011, 0x0066, 0x0001, 0x0002, 4, 7, 0x5599, 0x5599, 0x559a, 0, 2, 0, 4, 0, 6, 0, 8, 0, 10, 0, 12, 0xfffe, 0x7ffe, 0xfffa]

@cocotb.test()
async def test_vc_cpu(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # reset
    dut._log.info("reset")
    # reset
    dut.rst_n.value = 0
    # set a different compare value
    dut.ui_in.value = 3
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # check all values
    for i in range(29):
        dut._log.info("check output {}".format(i))
        dut._log.info("expected value {}".format(outputs[i]))
        while 1 :
            await ClockCycles(dut.clk, 1)
            if int(dut.log.value) == 1:
                dut._log.info("read value {}".format(int(dut.log_out.value)))
                assert int(dut.log_out.value) == outputs[i]
                break
