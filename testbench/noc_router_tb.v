`timescale 1ns/1ps
`include "../rtl/config/router_params.vh"

module noc_router_tb;

    // Parameters
    localparam CLK_PERIOD = 10;
    localparam SIM_TIME = 10000;
    
    // Signals
    reg clk;
    reg rst_n;
    
    // Router interfaces
    wire [`FLIT_WIDTH-1:0] north_in_data, south_in_data, east_in_data, west_in_data, local_in_data;
    wire north_in_valid, south_in_valid, east_in_valid, west_in_valid, local_in_valid;
    wire north_in_ready, south_in_ready, east_in_ready, west_in_ready, local_in_ready;
    
    wire [`FLIT_WIDTH-1:0] north_out_data, south_out_data, east_out_data, west_out_data, local_out_data;
    wire north_out_valid, south_out_valid, east_out_valid, west_out_valid, local_out_valid;
    wire north_out_ready, south_out_ready, east_out_ready, west_out_ready, local_out_ready;
    
    wire [31:0] status_reg;
    
    // Test variables
    integer test_packets_sent = 0;
    integer test_packets_received = 0;
    integer test_errors = 0;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Reset generation
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end
    
    // DUT instantiation
    router_core #(
        .ROUTER_ID(5),
        .X_COORD(1),
        .Y_COORD(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        
        .north_in_data(north_in_data),
        .north_in_valid(north_in_valid),
        .north_in_ready(north_in_ready),
        
        .south_in_data(south_in_data),
        .south_in_valid(south_in_valid),
        .south_in_ready(south_in_ready),
        
        .east_in_data(east_in_data),
        .east_in_valid(east_in_valid),
        .east_in_ready(east_in_ready),
        
        .west_in_data(west_in_data),
        .west_in_valid(west_in_valid),
        .west_in_ready(west_in_ready),
        
        .local_in_data(local_in_data),
        .local_in_valid(local_in_valid),
        .local_in_ready(local_in_ready),
        
        .north_out_data(north_out_data),
        .north_out_valid(north_out_valid),
        .north_out_ready(north_out_ready),
        
        .south_out_data(south_out_data),
        .south_out_valid(south_out_valid),
        .south_out_ready(south_out_ready),
        
        .east_out_data(east_out_data),
        .east_out_valid(east_out_valid),
        .east_out_ready(east_out_ready),
        
        .west_out_data(west_out_data),
        .west_out_valid(west_out_valid),
        .west_out_ready(west_out_ready),
        
        .local_out_data(local_out_data),
        .local_out_valid(local_out_valid),
        .local_out_ready(local_out_ready),
        
        .status_reg(status_reg)
    );
    
    // Traffic generators
    initial begin
        // Initialize
        north_in_valid = 0;
        south_in_valid = 0;
        east_in_valid = 0;
        west_in_valid = 0;
        local_in_valid = 0;
        
        north_out_ready = 1;
        south_out_ready = 1;
        east_out_ready = 1;
        west_out_ready = 1;
        local_out_ready = 1;
        
        // Wait for reset
        @(posedge rst_n);
        #100;
        
        // Test 1: Local to North routing
        $display("Test 1: Local to North routing");
        send_packet(5, 1, 0, 1); // From router 5 to router 1
        
        // Test 2: Multiple packets
        repeat(10) begin
            #50;
            send_random_packet();
        end
        
        // Test 3: Backpressure test
        $display("Testing backpressure...");
        north_out_ready = 0;
        repeat(5) send_random_packet();
        #200;
        north_out_ready = 1;
        
        // Wait for completion
        #1000;
        
        // Report results
        $display("\n=== Test Summary ===");
        $display("Packets sent: %0d", test_packets_sent);
        $display("Packets received: %0d", test_packets_received);
        $display("Errors: %0d", test_errors);
        
        if (test_errors == 0) begin
            $display("TEST PASSED!");
        end else begin
            $display("TEST FAILED!");
        end
        
        $finish;
    end
    
    // Packet sending task
    task send_packet;
        input [3:0] src;
        input [3:0] dest;
        input [31:0] data;
        input [7:0] pkt_id;
        begin
            // Header flit
            local_in_data = {dest, src, pkt_id, `HEADER_FLIT};
            local_in_valid = 1;
            @(posedge clk);
            while(!local_in_ready) @(posedge clk);
            
            // Data flit
            local_in_data = {data, `BODY_FLIT};
            @(posedge clk);
            while(!local_in_ready) @(posedge clk);
            
            // Tail flit
            local_in_data = {data + 1, `TAIL_FLIT};
            @(posedge clk);
            while(!local_in_ready) @(posedge clk);
            
            local_in_valid = 0;
            test_packets_sent++;
        end
    endtask
    
    task send_random_packet;
        begin
            automatic bit [3:0] src = $random % 16;
            automatic bit [3:0] dest = $random % 16;
            automatic bit [31:0] data = $random;
            automatic bit [7:0] pkt_id = test_packets_sent;
            
            send_packet(src, dest, data, pkt_id);
        end
    endtask
    
    // Monitor received packets
    always @(posedge clk) begin
        if (local_out_valid && local_out_ready) begin
            test_packets_received++;
            $display("Packet received: %h", local_out_data);
        end
    end
    
    // Timeout
    initial begin
        #SIM_TIME;
        $display("Simulation timeout!");
        $finish;
    end
    
    // Waveform dumping
    initial begin
        $dumpfile("noc_router_tb.vcd");
        $dumpvars(0, noc_router_tb);
    end

endmodule