//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: Matbi / Austin
//
// Create Date: 2021.01.31
// Design Name: 
// Module Name: data_mover_bram
// Project Name:
// Target Devices:
// Tool Versions:
// Description: To study ctrl sram. (WRITE / READ)
//				FSM + mem I/F
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
 
`timescale 1ns / 1ps
module data_mover_bram
// Param
#(
	parameter CNT_BIT = 31,
// BRAM
	parameter DWIDTH = 32,
	parameter AWIDTH = 12,
	parameter MEM_SIZE = 4096,
// Delay cycle
	parameter CORE_DELAY = 5
)

(
    input 				clk,
    input 				reset_n,
	input 				i_run,
	input  [CNT_BIT-1:0]	i_num_cnt,
	output   			o_idle,
	output   			o_read,
	output   			o_write,
	output  			o_done,

// Memory I/F (Read from bram0)
	output[AWIDTH-1:0] 	addr_b0,
	output 				ce_b0,
	output 				we_b0,
	input [DWIDTH-1:0]  q_b0,
	output[DWIDTH-1:0] 	d_b0,

// Memory I/F (Write to bram1)
	output[AWIDTH-1:0] 	addr_b1,
	output 				ce_b1,
	output 				we_b1,
	input [DWIDTH-1:0]  q_b1,
	output[DWIDTH-1:0] 	d_b1
    );

/////// Local Param. to define state ////////
localparam S_IDLE	= 2'b00;
localparam S_RUN	= 2'b01;
localparam S_DONE  	= 2'b10;

/////// Type ////////
reg [1:0] c_state_read; // Current state  (F/F)
reg [1:0] n_state_read; // Next state (Variable in Combinational Logic)
reg [1:0] c_state_write; // Current state  (F/F)
reg [1:0] n_state_write; // Next state (Variable in Combinational Logic)
wire	  is_write_done;
wire	  is_read_done;

/////// Main ////////

// Step 1. always block to update state 
always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
		c_state_read <= S_IDLE;
    end else begin
		c_state_read <= n_state_read;
    end
end

always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
		c_state_write <= S_IDLE;
    end else begin
		c_state_write <= n_state_write;
    end
end

// Step 2. always block to compute n_state_read
//always @(c_state_read or i_run or is_done) 
always @(*) 
begin
	n_state_read = c_state_read; // To prevent Latch.
	case(c_state_read)
	S_IDLE	: if(i_run)
				n_state_read = S_RUN;
	S_RUN   : if(is_read_done)
				n_state_read = S_DONE;
	S_DONE	: n_state_read 	 = S_IDLE;
	endcase
end 

always @(*) 
begin
	n_state_write = c_state_write; // To prevent Latch.
	case(c_state_write)
	S_IDLE	: if(i_run)
				n_state_write = S_RUN;
	S_RUN   : if(is_write_done)
				n_state_write = S_DONE;
	S_DONE	: n_state_write   = S_IDLE;
	endcase
end 

// Step 3.  always block to compute output
// Added to communicate with control signals.
assign o_idle 		= (c_state_read == S_IDLE) && (c_state_write == S_IDLE);
assign o_read 		= (c_state_read == S_RUN);
assign o_write 		= (c_state_write == S_RUN);
assign o_done 		= (c_state_write == S_DONE); // The write state is slower than the read state.

// Step 4. Registering (Capture) number of Count
reg [CNT_BIT-1:0] num_cnt;  
always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        num_cnt <= 0;  
    end else if (i_run) begin
        num_cnt <= i_num_cnt;
	end else if (o_done) begin
		num_cnt <= 0;
	end
end

// Step 5. increased addr_cnt
reg [CNT_BIT-1:0] addr_cnt_read;  
reg [CNT_BIT-1:0] addr_cnt_write;
assign is_read_done  = o_read  && (addr_cnt_read == num_cnt-1);
assign is_write_done = o_write && (addr_cnt_write == num_cnt-1);

always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        addr_cnt_read <= 0;  
    end else if (is_read_done) begin
        addr_cnt_read <= 0; 
    end else if (o_read) begin
        addr_cnt_read <= addr_cnt_read + 1;
	end
end

always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        addr_cnt_write <= 0;  
    end else if (is_write_done) begin
        addr_cnt_write <= 0; 
    end else if (o_write && we_b1) begin  // core delay
        addr_cnt_write <= addr_cnt_write + 1;
	end
end

// Step 6. Read Data from BRAM0
// Assign Memory I/F. Read from BRAM0
assign addr_b0 	= addr_cnt_read;
assign ce_b0 	= o_read;
assign we_b0 	= 1'b0; // read only
assign d_b0		= {DWIDTH{1'b0}}; // no use

reg 				r_valid;
wire [DWIDTH-1:0] 	mem_data;

// 1 cycle latency to sync mem output
always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        r_valid <= {DWIDTH{1'b0}};  
    end else begin
		r_valid <= o_read; // read data
	end
end
assign mem_data = q_b0;  

// Step 7. Pipeline 5 cycle (F/F delay)  (TODO Replace Core)
reg	 [CORE_DELAY-1:0] r_core_delay;
reg	 [DWIDTH-1:0] r_core_data[CORE_DELAY-1:0];

// Shift Delay
always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        r_core_delay <= 0;  
    end else begin
		r_core_delay <= {r_core_delay[CORE_DELAY-2:0], r_valid}; // read data
	end
end

// Shift Data
genvar  idx;
generate
    for (idx = 0; idx < CORE_DELAY-1; idx = idx + 1) begin : gen_core_delay
        always @(posedge clk or negedge reset_n) begin
            if(!reset_n) begin
                r_core_data[idx+1]   <= {DWIDTH{1'b0}};
            //end else if(|r_core_delay) begin // (lab16) bug. when run second time, remaining data.
            end else begin
                r_core_data[idx+1]   <= r_core_data[idx];
            end
        end
    end
endgenerate

// first one
always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        r_core_data[0] <= {DWIDTH{1'b0}};  
    //end else if(|r_core_delay) begin // (lab16) bug. when run second time, remaining data.
    end else begin
		r_core_data[0]	<= mem_data; // read data
	end
end

// Step 8. Write Data to BRAM1
assign addr_b1 	= addr_cnt_write;
assign ce_b1 	= r_core_delay[CORE_DELAY-1];
assign we_b1 	= r_core_delay[CORE_DELAY-1];
assign d_b1		= r_core_data[CORE_DELAY-1];  // core value;
//assign q_b1; // no use

endmodule
