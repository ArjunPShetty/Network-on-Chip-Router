`include "../config/router_params.vh"

module vc_allocator (
    input  wire                     clk,
    input  wire                     rst_n,
    
    // VC Requests
    input  wire [VC_NUM-1:0]        vc_req [0:`PORT_NUM-1],
    
    // VC Grants
    output reg [VC_NUM-1:0]         vc_grant [0:`PORT_NUM-1],
    
    // Credit information
    input  wire [VC_NUM-1:0]        credit_available [0:`PORT_NUM-1],
    
    // Status
    output wire                     allocator_busy
);

    // Internal state
    reg [1:0] rr_ptr [0:`PORT_NUM-1];
    reg alloc_active;
    
    // VC allocation logic per port
    generate
        for (genvar port = 0; port < `PORT_NUM; port++) begin : port_alloc
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    vc_grant[port] <= 0;
                    rr_ptr[port] <= 0;
                end else begin
                    vc_grant[port] <= 0;
                    
                    if (|vc_req[port]) begin
                        // Find available VC (round-robin)
                        for (int i = 0; i < VC_NUM; i++) begin
                            integer vc_idx = (rr_ptr[port] + i) % VC_NUM;
                            if (vc_req[port][vc_idx] && credit_available[port][vc_idx]) begin
                                vc_grant[port][vc_idx] <= 1'b1;
                                rr_ptr[port] <= (vc_idx + 1) % VC_NUM;
                                break;
                            end
                        end
                    end
                end
            end
        end
    endgenerate
    
    // Busy signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alloc_active <= 0;
        end else begin
            alloc_active <= |vc_req[0] || |vc_req[1] || |vc_req[2] || 
                           |vc_req[3] || |vc_req[4];
        end
    end
    
    assign allocator_busy = alloc_active;

endmodule