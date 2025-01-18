`timescale 1ns / 1ps


module axi4_lite_master#(
parameter ADDRESS = 32,
parameter DATA_WIDTH = 32
)
(
//Global Signals
input                           ACLK,
input                           ARESETN,

input                           START_READ,
input                           START_WRITE,
input                           LAST,

input   [ADDRESS-1:0]           address,
input   [DATA_WIDTH-1:0]        W_data,

//Read Address Channel INPUTS
input                           M_ARREADY,
//Read Data Channel INPUTS
input          [DATA_WIDTH-1:0] M_RDATA,
input                           M_RRESP,
input                           M_RVALID,
//Write Address Channel INPUTS
input                           M_AWREADY,
//Write Data Channel INPUTS
input                           M_WREADY,
//Write Response Channel INPUTS
input                           M_BRESP,
input                           M_BVALID,
//Read Address Channel OUTPUTS
output logic    [ADDRESS-1:0]   M_ARADDR,
output logic                    M_ARVALID,
//Read Data Channel OUTPUTS
output logic                    M_RREADY,
output wire [DATA_WIDTH-1:0] R_data,
//Write Address Channel OUTPUTS
output logic    [ADDRESS-1:0]   M_AWADDR,
output logic                    M_AWVALID,
//Write Data  Channel OUTPUTS
output logic   [DATA_WIDTH-1:0] M_WDATA,
output logic   [3:0]            M_WSTRB,
output logic                    M_WVALID,
//Write Response Channel OUTPUTS
output logic                    M_BREADY	
);
logic read_start,write_start,write_addr,write_data;

typedef enum logic [2 : 0] {IDLE,WRITE_CHANNEL,WRESP__CHANNEL, RADDR_CHANNEL, RDATA__CHANNEL} state_type;
state_type state, next_state;

//ar
assign M_ARADDR  = (state == RDATA__CHANNEL || state == RADDR_CHANNEL) ? address : 32'h0;
assign M_ARVALID = (state == RADDR_CHANNEL) ? 1 : 0;
//r
assign M_RREADY  = (state == RDATA__CHANNEL ||state == RADDR_CHANNEL) ? 1 : 0;
assign R_data = M_RDATA;
//aw
assign M_AWVALID = (state == WRITE_CHANNEL) ? 1 : 0;
assign M_AWADDR  = (state == WRITE_CHANNEL) ? address : 32'h0;
assign write_addr = M_AWVALID && M_AWREADY;
assign write_data = M_WVALID && M_WREADY;
//W
assign M_WVALID  = (state == WRITE_CHANNEL) ? 1 : 0;
assign M_WREADY  = (state == WRITE_CHANNEL) ? 1 : 0;
assign M_WDATA   = (state == WRITE_CHANNEL) ? W_data : 32'h0;
assign M_WSTRB   = (state == WRITE_CHANNEL)  ?4'b1111:0;
// B
assign M_BREADY = ((state == WRITE_CHANNEL)||(state == WRESP__CHANNEL)) ? 1 : 0;


always_ff @(posedge ACLK) begin
        if (~ARESETN) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
always_ff @(posedge ACLK) begin
        if (~ARESETN) begin
           read_start<=0;
           write_start<=0;
       end else begin
           read_start<=START_READ;
           write_start<=START_WRITE;
         end
    end
    
always_comb begin
		   case (state)
                  IDLE : begin
                      if (write_start) begin
                          next_state = WRITE_CHANNEL;
                      end else if (read_start) begin
                          next_state = RADDR_CHANNEL;
                      end else begin
                       next_state = IDLE;
                  end
              end
			RADDR_CHANNEL  : if (M_ARVALID && M_ARREADY) next_state = RDATA__CHANNEL;
			RDATA__CHANNEL : begin if (M_RVALID  && M_RREADY && LAST ) begin
                                 next_state = IDLE;
                                 end else if (read_start) begin
                                    next_state = RADDR_CHANNEL;
                                 end
                            end
            WRITE_CHANNEL: begin if (write_addr && write_data && LAST) begin
                                next_state = WRESP__CHANNEL; // Retaining the double underscores
                                end else begin
                                next_state = WRITE_CHANNEL;
                                end
                            end           
            WRESP__CHANNEL : if (M_BVALID  && M_BREADY ) next_state = IDLE;
			default : next_state = IDLE;
		endcase
	end


endmodule