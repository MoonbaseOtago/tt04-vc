`default_nettype none
`timescale 1ns/1ps

/*
this testbench just instantiates the module and makes some convenient wires
that can be driven / tested by the cocotb test.py
*/

// testbench is controlled by test.py
module tb ();

    // this part dumps the trace to a vcd file that can be viewed with GTKWave
    initial begin
        $dumpfile ("tb.vcd");
        $dumpvars (0, tb);
        #1;
    end

    // wire up the inputs and outputs
    reg  clk;
    reg  rst_n;
    wire  ena=1;
    wire  [7:0] ui_in;
    wire  [7:0] uio_in;

    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    tt_um_vc_cpu tt_um_vc_cpu (
    // include power ports for the Gate Level test
    `ifdef GL_TEST
        .VPWR( 1'b1),
        .VGND( 1'b0),
    `endif
        .ui_in      (ui_in),    // Dedicated inputs
        .uo_out     (uo_out),   // Dedicated outputs
        .uio_in     (uio_in),   // IOs: Input path
        .uio_out    (uio_out),  // IOs: Output path
        .uio_oe     (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
        .ena        (ena),      // enable - goes high when design is selected
        .clk        (clk),      // clock
        .rst_n      (rst_n)     // not reset
        );

	reg [7:0]m[0:4096];

	initial begin
`include "./init.v"
	end

	wire ind = uio_out[0];
	wire write = uio_out[1];
	wire latch_hi = uio_out[2];
	wire latch_lo = uio_out[3];
	assign uio_in[7] = 0; // interrupt

	reg [15:8]addrhi;
	reg [7:1]addrlo;

	assign ui_in = m[{addrhi, addrlo, ind}];

	always @(negedge clk)
	if (latch_hi) 
		addrhi <= uo_out;
	always @(negedge clk)
	if (latch_lo) 
		addrlo <= uo_out[7:1];
	always @(posedge clk)
	if (write) 
		m[{addrhi, addrlo, ind}] <= uo_out;

`ifdef XTEST
	initial begin
		rst_n = 0;
		clk=0; #5 clk=1; #5;
		clk=0; #5 clk=1; #5;
		rst_n = 1;
		forever begin clk=0; #5 clk=1; #5; end
	end
	initial begin
		#10000;$finish;
	end
`endif

endmodule
