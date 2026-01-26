`include "../config/router_params.vh"
`include "../config/network_config.vh"

module router_core #(
    parameter ROUTER_ID = 0,
    parameter X_COORD = 0,
    parameter Y_COORD = 0
)(
    // Global Signals
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Input Ports (North, South, East, West, Local)
    input  wire [`FLIT_WIDTH-1:0]   north_in_data,
    input  wire                     north_in_valid,
    output wire                     north_in_ready,
    
    input  wire [`FLIT_WIDTH-1:0]   south_in_data,
    input  wire                     south_in_valid,
    output wire                     south_in_ready,
    
    input  wire [`FLIT_WIDTH-1:0]   east_in_data,
    input  wire                     east_in_valid,
    output wire                     east_in_ready,
    
    input  wire [`FLIT_WIDTH-1:0]   west_in_data,
    input  wire                     west_in_valid,
    output wire                     west_in_ready,
    
    input  wire [`FLIT_WIDTH-1:0]   local_in_data,
    input  wire                     local_in_valid,
    output wire                     local_in_ready,
    
    // Output Ports
    output wire [`FLIT_WIDTH-1:0]   north_out_data,
    output wire                     north_out_valid,
    input  wire                     north_out_ready,
    
    output wire [`FLIT_WIDTH-1:0]   south_out_data,
    output wire                     south_out_valid,
    input  wire                     south_out_ready,
    
    output wire [`FLIT_WIDTH-1:0]   east_out_data,
    output wire                     east_out_valid,
    input  wire                     east_out_ready,
    
    output wire [`FLIT_WIDTH-1:0]   west_out_data,
    output wire                     west_out_valid,
    input  wire                     west_out_ready,
    
    output wire [`FLIT_WIDTH-1:0]   local_out_data,
    output wire                     local_out_valid,
    input  wire                     local_out_ready,
    
    // Configuration and Monitoring
    input  wire [31:0]              config_reg,
    output wire [31:0]              status_reg,
    output perf_counters_t          perf_counters
);

    // Internal Signals
    wire [`FLIT_WIDTH-1:0]  input_data  [0:`PORT_NUM-1];
    wire                    input_valid [0:`PORT_NUM-1];
    wire                    input_ready [0:`PORT_NUM-1];
    
    wire [`FLIT_WIDTH-1:0]  output_data [0:`PORT_NUM-1];
    wire                    output_valid[0:`PORT_NUM-1];
    wire                    output_ready[0:`PORT_NUM-1];
    
    wire [2:0]              route_req   [0:`PORT_NUM-1][0:`PORT_NUM-1];
    wire                    route_grant [0:`PORT_NUM-1][0:`PORT_NUM-1];
    wire [1:0]              vc_id_out   [0:`PORT_NUM-1];
    
    // Assign input/output ports to arrays
    assign input_data[0] = north_in_data;
    assign input_valid[0] = north_in_valid;
    assign north_in_ready = input_ready[0];
    
    assign input_data[1] = south_in_data;
    assign input_valid[1] = south_in_valid;
    assign south_in_ready = input_ready[1];
    
    assign input_data[2] = east_in_data;
    assign input_valid[2] = east_in_valid;
    assign east_in_ready = input_ready[2];
    
    assign input_data[3] = west_in_data;
    assign input_valid[3] = west_in_valid;
    assign west_in_ready = input_ready[3];
    
    assign input_data[4] = local_in_data;
    assign input_valid[4] = local_in_valid;
    assign local_in_ready = input_ready[4];
    
    assign north_out_data = output_data[0];
    assign north_out_valid = output_valid[0];
    assign output_ready[0] = north_out_ready;
    
    assign south_out_data = output_data[1];
    assign south_out_valid = output_valid[1];
    assign output_ready[1] = south_out_ready;
    
    assign east_out_data = output_data[2];
    assign east_out_valid = output_valid[2];
    assign output_ready[2] = east_out_ready;
    
    assign west_out_data = output_data[3];
    assign west_out_valid = output_valid[3];
    assign output_ready[3] = west_out_ready;
    
    assign local_out_data = output_data[4];
    assign local_out_valid = output_valid[4];
    assign output_ready[4] = local_out_ready;
    
    // Instantiate Input Ports
    genvar i;
    generate
        for (i = 0; i < `PORT_NUM; i = i + 1) begin : input_ports
            input_port #(
                .PORT_ID(i)
            ) u_input_port (
                .clk(clk),
                .rst_n(rst_n),
                .flit_in(input_data[i]),
                .flit_in_valid(input_valid[i]),
                .flit_in_ready(input_ready[i]),
                .flit_out(),
                .flit_out_valid(),
                .route_req(route_req[i]),
                .route_grant(route_grant[i]),
                .vc_id_out(vc_id_out[i]),
                .buffer_status()
            );
        end
    endgenerate
    
    // Instantiate Switch Allocator
    switch_allocator u_switch_allocator (
        .clk(clk),
        .rst_n(rst_n),
        .route_req(route_req),
        .route_grant(route_grant),
        .vc_id(vc_id_out),
        .allocator_busy()
    );
    
    // Instantiate Crossbar
    crossbar u_crossbar (
        .clk(clk),
        .rst_n(rst_n),
        .input_data(input_data),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .output_data(output_data),
        .output_valid(output_valid),
        .output_ready(output_ready),
        .switch_config(route_grant)
    );
    
    // Performance Counters
    reg [31:0] flit_counter_rx, flit_counter_tx;
    reg [31:0] packet_counter_rx, packet_counter_tx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flit_counter_rx <= 0;
            flit_counter_tx <= 0;
            packet_counter_rx <= 0;
            packet_counter_tx <= 0;
        end else begin
            // Count received flits
            for (int j = 0; j < `PORT_NUM; j++) begin
                if (input_valid[j] && input_ready[j]) 
                    flit_counter_rx <= flit_counter_rx + 1;
            end
            
            // Count transmitted flits
            for (int j = 0; j < `PORT_NUM; j++) begin
                if (output_valid[j] && output_ready[j]) 
                    flit_counter_tx <= flit_counter_tx + 1;
            end
        end
    end
    
    assign perf_counters.flits_received = flit_counter_rx;
    assign perf_counters.flits_sent = flit_counter_tx;
    assign perf_counters.packets_received = packet_counter_rx;
    assign perf_counters.packets_sent = packet_counter_tx;
    
    assign status_reg = {24'b0, 
                        input_ready[4], input_ready[3], input_ready[2], 
                        input_ready[1], input_ready[0], 
                        output_valid[4], output_valid[3], output_valid[2], 
                        output_valid[1], output_valid[0]};

endmodule