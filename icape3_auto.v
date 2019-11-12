//
// Source code:
// https://github.com/mariko-poyo/capstone/blob/master/customIP/auto_reset_10bits_1.0/src/icape3_auto.v
//
// Lastweek notes:
// - This one is using ICAP to reprogram the whole chip. IPROG.
// - No readback.
//

`timescale 1ns / 1ps

module icap3_reset(
		clk,
		reset_signal,
		temp_in,
		temp_thresh,
		thresh_valid
	);

	//define input/output 
	input clk;
	input reset_signal;
	input [9:0] temp_in;
	input [9:0] temp_thresh;
	input thresh_valid;

	//parameter
	parameter CCOUNT = 8;

	//define regs
	reg [3:0] cnt_bitst;
	reg reboot;
	reg reprog;
	reg icap_cs;
	reg icap_rw;
	reg [31:0] d;
	reg [31:0] bit_swapped;
	reg [9:0] temperature_threshold;

	//define wire and assign it
	wire overheating;
	assign overheating = (temp_in >= temperature_threshold)?(1'b1):(1'b0);

	//intialize
	initial cnt_bitst = 0;
	initial reboot = 0;
	initial reprog = 0;
	initial icap_cs = 1;
	initial icap_rw = 1;
	initial d = 32'hFBFFFFAC;
	initial bit_swapped = 32'hFFFFFFFF;
	initial temperature_threshold = 10'b1011011100; //initialize temperature threshold to be 732 (around 85 celsius degree)

	//instantiate icap3 module
	ICAPE3 icape3_inst(
		.CLK(clk),
		.CSIB(icap_cs),
		.I(bit_swapped),
		.RDWRB(icap_rw),
		.O(),
		.AVAIL(),
		.PRDONE(),
		.PRERROR()
	);

	//FSM
	always@(posedge clk)
	begin
		if(reset_signal == 1'b1 || overheating == 1'b1)
		begin
			reboot <= 1;
		end
		
		if(thresh_valid == 1'b1)
		begin
			temperature_threshold <= temp_thresh; 
		end

		if(reboot == 0)
		begin
			icap_cs <= 1;
			icap_rw <= 1;
			cnt_bitst <= 0;
		end
		else
		begin
			if(cnt_bitst != CCOUNT) 
			begin
				cnt_bitst <= cnt_bitst + 1;
			end

			case(cnt_bitst)
				4'd0:
				begin
					icap_cs <= 0;
					icap_rw <= 0;
				end
				4'd1: d <= 32'hFFFFFFFF; //dummy word
				4'd2: d <= 32'hAA995566; //sync word
				4'd3: d <= 32'h20000000; // NOOP
				4'd4: d <= 32'h30020001; //write 1 word to WBSTAR
				4'd5: d <= 32'h00000000; //warm boot start address
				4'd6: d <= 32'h20000000; //NOOP
				4'd7: d <= 32'h30008001; //write 1 word to CMD
				4'd8: d <= 32'h0000000F; //IPROG command
				default:
				begin
					icap_cs <= 1;
					icap_rw <= 1;
				end
			endcase
		end

		//bit swap
		bit_swapped[31:24] <= {d[24],d[25],d[26],d[27],d[28],d[29],d[30],d[31]};
		bit_swapped[23:16] <= {d[16],d[17],d[18],d[19],d[20],d[21],d[22],d[23]};
		bit_swapped[15:8] <= {d[8],d[9],d[10],d[11],d[12],d[13],d[14],d[15]};
		bit_swapped[7:0] <= {d[0],d[1],d[2],d[3],d[4],d[5],d[6],d[7]};

	end //end of always block
endmodule
