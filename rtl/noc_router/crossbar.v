`include "../config/router_params.vh"

module crossbar (
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Input interfaces
    input  wire [`FLIT_WIDTH-1:0]   input_data [0:`PORT_NUM-1],
    input  wire                     input_valid [0:`PORT_NUM-1],
    output wire                     input_ready [0:`PORT_NUM-1],
    
    // Output interfaces
    output wire [`FLIT_WIDTH-1:0]   output_data [0:`PORT_NUM-1],
    output wire                     output_valid [0:`PORT_NUM-1],
    input  wire                     output_ready [0:`PORT_NUM-1],
    
    // Switch configuration
    input  wire                     switch_config [0:`PORT_NUM-1][0:`PORT_NUM-1]
);

    // Crosspoint registers
    reg [`FLIT_WIDTH-1:0] crosspoint_data [0:`PORT_NUM-1];
    reg crosspoint_valid [0:`PORT_NUM-1];
    
    // Connection matrix
    wire [0:`PORT_NUM-1] connection_matrix [0:`PORT_NUM-1];
    
    // Generate connection matrix
    generate
        for (genvar i = 0; i < `PORT_NUM; i++) begin
            for (genvar j = 0; j < `PORT_NUM; j++) begin
                assign connection_matrix[i][j] = switch_config[i][j];
            end
        end
    endgenerate
    
    // Crossbar switching logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < `PORT_NUM; i++) begin
                crosspoint_data[i] <= 0;
                crosspoint_valid[i] <= 0;
            end
        end else begin
            // Clear previous outputs
            for (int i = 0; i < `PORT_NUM; i++) begin
                crosspoint_valid[i] <= 0;
            end
            
            // Establish new connections
            for (int in_port = 0; in_port < `PORT_NUM; in_port++) begin
                for (int out_port = 0; out_port < `PORT_NUM; out_port++) begin
                    if (connection_matrix[in_port][out_port] && 
                        input_valid[in_port] && output_ready[out_port]) begin
                        crosspoint_data[out_port] <= input_data[in_port];
                        crosspoint_valid[out_port] <= 1'b1;
                    end
                end
            end
        end
    end
    
    // Assign outputs
    generate
        for (genvar i = 0; i < `PORT_NUM; i++) begin
            assign output_data[i] = crosspoint_data[i];
            assign output_valid[i] = crosspoint_valid[i];
        end
    endgenerate
    
    // Input ready logic (simplified)
    generate
        for (genvar i = 0; i < `PORT_NUM; i++) begin
            // Input is ready if any output can accept it
            wire any_output_ready;
            assign any_output_ready = |output_ready;
            assign input_ready[i] = any_output_ready && input_valid[i];
        end
    endgenerate

endmodule