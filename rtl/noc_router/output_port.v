`include "../config/router_params.vh"

module output_port #(
    parameter PORT_ID = 0
)(
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Crossbar Interface
    input  wire [`FLIT_WIDTH-1:0]   flit_in,
    input  wire                     flit_in_valid,
    output wire                     flit_in_ready,
    
    // Output Interface
    output wire [`FLIT_WIDTH-1:0]   flit_out,
    output wire                     flit_out_valid,
    input  wire                     flit_out_ready,
    
    // Credit-based Flow Control
    input  wire [VC_NUM-1:0]        credit_in,
    output wire [VC_NUM-1:0]        credit_out
);

    // Output FIFO
    reg [`FLIT_WIDTH-1:0] output_fifo [0:3];
    reg [1:0] fifo_wr_ptr, fifo_rd_ptr;
    reg [2:0] fifo_count;
    
    // Credit counters
    reg [2:0] credit_counter [0:VC_NUM-1];
    
    // Flit pipeline register
    reg [`FLIT_WIDTH-1:0] flit_reg;
    reg flit_reg_valid;
    
    // FIFO Write Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_wr_ptr <= 0;
            fifo_rd_ptr <= 0;
            fifo_count <= 0;
            for (int i = 0; i < VC_NUM; i++) 
                credit_counter[i] <= `BUFFER_DEPTH;
            flit_reg_valid <= 0;
        end else begin
            // Write to FIFO
            if (flit_in_valid && flit_in_ready && fifo_count < 4) begin
                output_fifo[fifo_wr_ptr] <= flit_in;
                fifo_wr_ptr <= fifo_wr_ptr + 1;
                fifo_count <= fifo_count + 1;
            end
            
            // Read from FIFO
            if (flit_out_ready && fifo_count > 0 && !flit_reg_valid) begin
                flit_reg <= output_fifo[fifo_rd_ptr];
                fifo_rd_ptr <= fifo_rd_ptr + 1;
                fifo_count <= fifo_count - 1;
                flit_reg_valid <= 1;
            end
            
            // Clear output register when transmitted
            if (flit_out_valid && flit_out_ready) begin
                flit_reg_valid <= 0;
            end
            
            // Update credit counters
            for (int i = 0; i < VC_NUM; i++) begin
                if (credit_in[i] && credit_counter[i] < `BUFFER_DEPTH)
                    credit_counter[i] <= credit_counter[i] + 1;
                if (flit_in_valid && flit_in_ready && (flit_in[1:0] == i))
                    credit_counter[i] <= credit_counter[i] - 1;
            end
        end
    end
    
    // Flow Control Logic
    wire [VC_NUM-1:0] vc_available;
    generate
        for (genvar i = 0; i < VC_NUM; i++) begin
            assign vc_available[i] = (credit_counter[i] > 0);
        end
    endgenerate
    
    assign flit_in_ready = (|vc_available) && (fifo_count < 4);
    
    // Output assignments
    assign flit_out = flit_reg;
    assign flit_out_valid = flit_reg_valid;
    
    // Generate credit output
    assign credit_out = vc_available;

endmodule