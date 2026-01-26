`include "../config/router_params.vh"

module switch_allocator (
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Route Requests from Input Ports
    input  wire [2:0]               route_req [0:`PORT_NUM-1][0:`PORT_NUM-1],
    
    // Route Grants to Input Ports
    output reg                      route_grant [0:`PORT_NUM-1][0:`PORT_NUM-1],
    
    // Virtual Channel IDs
    input  wire [1:0]               vc_id [0:`PORT_NUM-1],
    
    // Status
    output wire                     allocator_busy
);

    // Internal state
    reg [2:0] arbiter_state [0:`PORT_NUM-1];
    reg [2:0] round_robin_ptr [0:`PORT_NUM-1];
    
    // Request matrix
    wire [(`PORT_NUM*3)-1:0] req_matrix [0:`PORT_NUM-1];
    reg [(`PORT_NUM*3)-1:0]  grant_matrix [0:`PORT_NUM-1];
    
    // Generate request matrix
    generate
        for (genvar i = 0; i < `PORT_NUM; i++) begin
            for (genvar j = 0; j < `PORT_NUM; j++) begin
                assign req_matrix[i][j*3 +: 3] = route_req[i][j];
            end
        end
    endgenerate
    
    // Round-robin arbiters for each output port
    generate
        for (genvar out_port = 0; out_port < `PORT_NUM; out_port++) begin : output_arbiters
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    round_robin_ptr[out_port] <= 0;
                    grant_matrix[out_port] <= 0;
                end else begin
                    // Find requests for this output port
                    reg found;
                    found = 0;
                    grant_matrix[out_port] <= 0;
                    
                    // Round-robin arbitration
                    for (int i = 0; i < `PORT_NUM; i++) begin
                        integer idx = (round_robin_ptr[out_port] + i) % `PORT_NUM;
                        if (req_matrix[idx][out_port*3 +: 3] != 0 && !found) begin
                            grant_matrix[out_port][idx*3 +: 3] <= 
                                req_matrix[idx][out_port*3 +: 3];
                            found = 1;
                            round_robin_ptr[out_port] <= (idx + 1) % `PORT_NUM;
                        end
                    end
                end
            end
        end
    endgenerate
    
    // Generate grant signals
    generate
        for (genvar in_port = 0; in_port < `PORT_NUM; in_port++) begin
            for (genvar out_port = 0; out_port < `PORT_NUM; out_port++) begin
                always @(*) begin
                    route_grant[in_port][out_port] = 
                        |(grant_matrix[out_port][in_port*3 +: 3]);
                end
            end
        end
    endgenerate
    
    // Busy signal
    wire any_grant;
    assign any_grant = |grant_matrix;
    assign allocator_busy = any_grant;

endmodule