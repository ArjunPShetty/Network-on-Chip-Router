`include "../config/router_params.vh"

module input_port #(
    parameter PORT_ID = 0
)(
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Input Interface
    input  wire [`FLIT_WIDTH-1:0]   flit_in,
    input  wire                     flit_in_valid,
    output wire                     flit_in_ready,
    
    // Output to Crossbar
    output wire [`FLIT_WIDTH-1:0]   flit_out,
    output wire                     flit_out_valid,
    
    // Routing Request/Grant
    output wire [2:0]               route_req [0:`PORT_NUM-1],
    input  wire                     route_grant [0:`PORT_NUM-1],
    
    // VC Management
    output wire [1:0]               vc_id_out,
    
    // Status
    output wire [7:0]               buffer_status
);

    // Virtual Channel Buffers
    reg [`FLIT_WIDTH-1:0] vc_buffer [0:`VC_NUM-1][0:`BUFFER_DEPTH-1];
    reg [2:0] vc_wr_ptr [0:`VC_NUM-1];
    reg [2:0] vc_rd_ptr [0:`VC_NUM-1];
    reg [3:0] vc_count [0:`VC_NUM-1];
    
    // Flit Register
    reg [`FLIT_WIDTH-1:0] current_flit;
    reg current_flit_valid;
    reg [1:0] current_vc;
    
    // Routing Logic
    reg [2:0] dest_port;
    wire [`DEST_X_WIDTH-1:0] dest_x;
    wire [`DEST_Y_WIDTH-1:0] dest_y;
    wire [`SRC_X_WIDTH-1:0] src_x;
    wire [`SRC_Y_WIDTH-1:0] src_y;
    
    // Extract packet headers
    assign dest_x = flit_in[`FLIT_WIDTH-1:`FLIT_WIDTH-`DEST_X_WIDTH];
    assign dest_y = flit_in[`FLIT_WIDTH-`DEST_X_WIDTH-1:`FLIT_WIDTH-`DEST_X_WIDTH-`DEST_Y_WIDTH];
    assign src_x = flit_in[`FLIT_WIDTH-`DEST_X_WIDTH-`DEST_Y_WIDTH-1:`FLIT_WIDTH-`DEST_X_WIDTH-`DEST_Y_WIDTH-`SRC_X_WIDTH];
    assign src_y = flit_in[`FLIT_WIDTH-`DEST_X_WIDTH-`DEST_Y_WIDTH-`SRC_X_WIDTH-1:`FLIT_WIDTH-`DEST_X_WIDTH-`DEST_Y_WIDTH-`SRC_X_WIDTH-`SRC_Y_WIDTH];
    
    // Buffer Write Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < `VC_NUM; i++) begin
                vc_wr_ptr[i] <= 0;
                vc_rd_ptr[i] <= 0;
                vc_count[i] <= 0;
            end
            current_flit_valid <= 0;
            current_vc <= 0;
        end else begin
            // Write incoming flit to buffer
            if (flit_in_valid && flit_in_ready) begin
                vc_buffer[current_vc][vc_wr_ptr[current_vc]] <= flit_in;
                vc_wr_ptr[current_vc] <= vc_wr_ptr[current_vc] + 1;
                vc_count[current_vc] <= vc_count[current_vc] + 1;
                
                // VC allocation (simple round-robin)
                current_vc <= (current_vc + 1) % `VC_NUM;
            end
            
            // Read from buffer when granted
            if (|route_grant && current_flit_valid) begin
                vc_rd_ptr[current_vc] <= vc_rd_ptr[current_vc] + 1;
                vc_count[current_vc] <= vc_count[current_vc] - 1;
                current_flit_valid <= 0;
            end
            
            // Load next flit from buffer
            if (!current_flit_valid && (|vc_count)) begin
                for (int i = 0; i < `VC_NUM; i++) begin
                    if (vc_count[i] > 0) begin
                        current_flit <= vc_buffer[i][vc_rd_ptr[i]];
                        current_vc <= i;
                        current_flit_valid <= 1;
                        break;
                    end
                end
            end
        end
    end
    
    // XY Routing Algorithm
    always @(*) begin
        if (current_flit_valid) begin
            case (`ROUTING_ALG)
                `XY_ROUTING: begin
                    if (dest_x > PORT_ID[1:0]) 
                        dest_port = 2; // East
                    else if (dest_x < PORT_ID[1:0]) 
                        dest_port = 3; // West
                    else if (dest_y > PORT_ID[3:2]) 
                        dest_port = 0; // North
                    else if (dest_y < PORT_ID[3:2]) 
                        dest_port = 1; // South
                    else 
                        dest_port = 4; // Local
                end
                default: dest_port = 4; // Local
            endcase
        end else begin
            dest_port = 0;
        end
    end
    
    // Generate route requests
    genvar j;
    generate
        for (j = 0; j < `PORT_NUM; j = j + 1) begin : route_req_gen
            assign route_req[j] = (dest_port == j && current_flit_valid) ? 
                                 (3'b001 << current_vc) : 3'b000;
        end
    endgenerate
    
    // Output assignments
    assign flit_out = current_flit;
    assign flit_out_valid = |route_grant;
    assign vc_id_out = current_vc;
    
    // Buffer status and ready signal
    wire buffer_not_full = (vc_count[current_vc] < `BUFFER_DEPTH);
    assign flit_in_ready = buffer_not_full;
    
    assign buffer_status = {vc_count[3], vc_count[2], vc_count[1], vc_count[0]};

endmodule