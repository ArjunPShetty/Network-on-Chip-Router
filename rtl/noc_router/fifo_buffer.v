`include "../config/router_params.vh"

module fifo_buffer #(
    parameter WIDTH = `FLIT_WIDTH,
    parameter DEPTH = `BUFFER_DEPTH
)(
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Write Interface
    input  wire [WIDTH-1:0]         data_in,
    input  wire                     wr_en,
    output wire                     full,
    
    // Read Interface
    output wire [WIDTH-1:0]         data_out,
    input  wire                     rd_en,
    output wire                     empty,
    
    // Status
    output wire [3:0]               count
);

    // Memory array
    reg [WIDTH-1:0] memory [0:DEPTH-1];
    
    // Pointers
    reg [2:0] wr_ptr, rd_ptr;
    reg [3:0] item_count;
    
    // Flags
    wire almost_full, almost_empty;
    
    // Write pointer logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            item_count <= 0;
        end else begin
            // Write operation
            if (wr_en && !full) begin
                memory[wr_ptr] <= data_in;
                wr_ptr <= wr_ptr + 1;
                item_count <= item_count + 1;
            end
            
            // Read operation
            if (rd_en && !empty) begin
                rd_ptr <= rd_ptr + 1;
                item_count <= item_count - 1;
            end
        end
    end
    
    // Output data (registered for better timing)
    reg [WIDTH-1:0] data_out_reg;
    always @(posedge clk) begin
        if (rd_en && !empty) begin
            data_out_reg <= memory[rd_ptr];
        end
    end
    
    // Status signals
    assign full = (item_count == DEPTH);
    assign empty = (item_count == 0);
    assign almost_full = (item_count >= DEPTH-1);
    assign almost_empty = (item_count <= 1);
    assign count = item_count;
    
    assign data_out = data_out_reg;

endmodule