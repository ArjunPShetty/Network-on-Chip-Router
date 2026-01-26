`include "../config/router_params.vh"

module noc_top #(
    parameter NET_X = `NETWORK_X,
    parameter NET_Y = `NETWORK_Y
)(
    input  wire                     clk,
    input  wire                     rst_n,
    
    // External Interfaces (one per node)
    input  wire [`FLIT_WIDTH-1:0]   ext_in_data  [0:(NET_X*NET_Y)-1],
    input  wire                     ext_in_valid [0:(NET_X*NET_Y)-1],
    output wire                     ext_in_ready [0:(NET_X*NET_Y)-1],
    
    output wire [`FLIT_WIDTH-1:0]   ext_out_data [0:(NET_X*NET_Y)-1],
    output wire                     ext_out_valid[0:(NET_X*NET_Y)-1],
    input  wire                     ext_out_ready[0:(NET_X*NET_Y)-1],
    
    // Monitoring
    output wire [31:0]              router_status [0:(NET_X*NET_Y)-1]
);

    // Router array signals
    wire [`FLIT_WIDTH-1:0]  router_data_out [0:NET_X-1][0:NET_Y-1][0:4];
    wire                    router_valid_out[0:NET_X-1][0:NET_Y-1][0:4];
    wire                    router_ready_out[0:NET_X-1][0:NET_Y-1][0:4];
    
    wire [`FLIT_WIDTH-1:0]  router_data_in  [0:NET_X-1][0:NET_Y-1][0:4];
    wire                    router_valid_in [0:NET_X-1][0:NET_Y-1][0:4];
    wire                    router_ready_in [0:NET_X-1][0:NET_Y-1][0:4];
    
    // Generate router grid
    genvar x, y;
    generate
        for (x = 0; x < NET_X; x = x + 1) begin : x_dim
            for (y = 0; y < NET_Y; y = y + 1) begin : y_dim
                // Calculate router ID
                localparam ROUTER_ID = (x * NET_Y) + y;
                
                // Instantiate router
                router_core #(
                    .ROUTER_ID(ROUTER_ID),
                    .X_COORD(x),
                    .Y_COORD(y)
                ) u_router (
                    .clk(clk),
                    .rst_n(rst_n),
                    
                    // North port
                    .north_in_data(router_data_in[x][y][0]),
                    .north_in_valid(router_valid_in[x][y][0]),
                    .north_in_ready(router_ready_in[x][y][0]),
                    
                    .north_out_data(router_data_out[x][y][0]),
                    .north_out_valid(router_valid_out[x][y][0]),
                    .north_out_ready(router_ready_out[x][y][0]),
                    
                    // South port
                    .south_in_data(router_data_in[x][y][1]),
                    .south_in_valid(router_valid_in[x][y][1]),
                    .south_in_ready(router_ready_in[x][y][1]),
                    
                    .south_out_data(router_data_out[x][y][1]),
                    .south_out_valid(router_valid_out[x][y][1]),
                    .south_out_ready(router_ready_out[x][y][1]),
                    
                    // East port
                    .east_in_data(router_data_in[x][y][2]),
                    .east_in_valid(router_valid_in[x][y][2]),
                    .east_in_ready(router_ready_in[x][y][2]),
                    
                    .east_out_data(router_data_out[x][y][2]),
                    .east_out_valid(router_valid_out[x][y][2]),
                    .east_out_ready(router_ready_out[x][y][2]),
                    
                    // West port
                    .west_in_data(router_data_in[x][y][3]),
                    .west_in_valid(router_valid_in[x][y][3]),
                    .west_in_ready(router_ready_in[x][y][3]),
                    
                    .west_out_data(router_data_out[x][y][3]),
                    .west_out_valid(router_valid_out[x][y][3]),
                    .west_out_ready(router_ready_out[x][y][3]),
                    
                    // Local port
                    .local_in_data(ext_in_data[ROUTER_ID]),
                    .local_in_valid(ext_in_valid[ROUTER_ID]),
                    .local_in_ready(ext_in_ready[ROUTER_ID]),
                    
                    .local_out_data(ext_out_data[ROUTER_ID]),
                    .local_out_valid(ext_out_valid[ROUTER_ID]),
                    .local_out_ready(ext_out_ready[ROUTER_ID]),
                    
                    // Monitoring
                    .status_reg(router_status[ROUTER_ID])
                );
                
                // Connect routers in mesh
                // North connections
                if (y < NET_Y-1) begin
                    assign router_data_in[x][y+1][1] = router_data_out[x][y][0];
                    assign router_valid_in[x][y+1][1] = router_valid_out[x][y][0];
                    assign router_ready_in[x][y+1][1] = router_ready_out[x][y][0];
                end else begin
                    assign router_data_in[x][y][0] = 0;
                    assign router_valid_in[x][y][0] = 0;
                    assign router_ready_out[x][y][0] = 1;
                end
                
                // South connections
                if (y > 0) begin
                    assign router_data_in[x][y-1][0] = router_data_out[x][y][1];
                    assign router_valid_in[x][y-1][0] = router_valid_out[x][y][1];
                    assign router_ready_in[x][y-1][0] = router_ready_out[x][y][1];
                end else begin
                    assign router_data_in[x][y][1] = 0;
                    assign router_valid_in[x][y][1] = 0;
                    assign router_ready_out[x][y][1] = 1;
                end
                
                // East connections
                if (x < NET_X-1) begin
                    assign router_data_in[x+1][y][3] = router_data_out[x][y][2];
                    assign router_valid_in[x+1][y][3] = router_valid_out[x][y][2];
                    assign router_ready_in[x+1][y][3] = router_ready_out[x][y][2];
                end else begin
                    assign router_data_in[x][y][2] = 0;
                    assign router_valid_in[x][y][2] = 0;
                    assign router_ready_out[x][y][2] = 1;
                end
                
                // West connections
                if (x > 0) begin
                    assign router_data_in[x-1][y][2] = router_data_out[x][y][3];
                    assign router_valid_in[x-1][y][2] = router_valid_out[x][y][3];
                    assign router_ready_in[x-1][y][2] = router_ready_out[x][y][3];
                end else begin
                    assign router_data_in[x][y][3] = 0;
                    assign router_valid_in[x][y][3] = 0;
                    assign router_ready_out[x][y][3] = 1;
                end
            end
        end
    endgenerate

endmodule