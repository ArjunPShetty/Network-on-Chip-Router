`include "../config/router_params.vh"

module ni_master #(
    parameter NODE_ID = 0
)(
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Processor Interface
    input  wire [31:0]              pkt_data_in,
    input  wire                     pkt_valid_in,
    output wire                     pkt_ready_in,
    
    output wire [31:0]              pkt_data_out,
    output wire                     pkt_valid_out,
    input  wire                     pkt_ready_out,
    
    // Router Interface
    output wire [`FLIT_WIDTH-1:0]   flit_out,
    output wire                     flit_out_valid,
    input  wire                     flit_out_ready,
    
    input  wire [`FLIT_WIDTH-1:0]   flit_in,
    input  wire                     flit_in_valid,
    output wire                     flit_in_ready,
    
    // Configuration
    input  wire [31:0]              dest_addr,
    input  wire                     start_transmit
);

    // Packet assembly/disassembly
    reg [31:0] packet_buffer [0:7];
    reg [2:0] pkt_wr_ptr, pkt_rd_ptr;
    reg [3:0] pkt_word_count;
    reg assembling_packet, transmitting;
    
    // Flit generator
    reg [`FLIT_WIDTH-1:0] flit_reg;
    reg flit_valid_reg;
    reg [1:0] flit_type;
    reg [7:0] packet_id;
    
    // Packet assembly
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pkt_wr_ptr <= 0;
            pkt_rd_ptr <= 0;
            pkt_word_count <= 0;
            assembling_packet <= 0;
            transmitting <= 0;
            flit_valid_reg <= 0;
            packet_id <= 0;
        end else begin
            // Receive packet from processor
            if (pkt_valid_in && pkt_ready_in) begin
                packet_buffer[pkt_wr_ptr] <= pkt_data_in;
                pkt_wr_ptr <= pkt_wr_ptr + 1;
                pkt_word_count <= pkt_word_count + 1;
                
                if (pkt_data_in[31]) begin // Last word flag
                    assembling_packet <= 1;
                end
            end
            
            // Start transmission
            if (start_transmit && pkt_word_count > 0 && !transmitting) begin
                transmitting <= 1;
                pkt_rd_ptr <= 0;
                flit_type <= `HEADER_FLIT;
                packet_id <= packet_id + 1;
            end
            
            // Generate flits
            if (transmitting && flit_out_ready) begin
                case (flit_type)
                    `HEADER_FLIT: begin
                        flit_reg <= {dest_addr, NODE_ID, packet_id, `HEADER_FLIT};
                        flit_type <= `BODY_FLIT;
                        flit_valid_reg <= 1;
                    end
                    `BODY_FLIT: begin
                        if (pkt_rd_ptr < pkt_word_count - 1) begin
                            flit_reg <= {packet_buffer[pkt_rd_ptr], `BODY_FLIT};
                            pkt_rd_ptr <= pkt_rd_ptr + 1;
                            flit_valid_reg <= 1;
                            
                            if (pkt_rd_ptr == pkt_word_count - 2) begin
                                flit_type <= `TAIL_FLIT;
                            end
                        end
                    end
                    `TAIL_FLIT: begin
                        flit_reg <= {packet_buffer[pkt_rd_ptr], `TAIL_FLIT};
                        flit_valid_reg <= 1;
                        transmitting <= 0;
                        assembling_packet <= 0;
                        pkt_word_count <= 0;
                    end
                    default: begin
                        flit_valid_reg <= 0;
                    end
                endcase
            end else begin
                flit_valid_reg <= 0;
            end
        end
    end
    
    // Packet disassembly (receiving from router)
    reg [31:0] rx_buffer [0:7];
    reg [2:0] rx_wr_ptr;
    reg [3:0] rx_word_count;
    reg receiving_packet;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_wr_ptr <= 0;
            rx_word_count <= 0;
            receiving_packet <= 0;
        end else if (flit_in_valid && flit_in_ready) begin
            case (flit_in[1:0])
                `HEADER_FLIT: begin
                    rx_wr_ptr <= 0;
                    receiving_packet <= 1;
                end
                `BODY_FLIT, `TAIL_FLIT: begin
                    if (receiving_packet) begin
                        rx_buffer[rx_wr_ptr] <= flit_in[63:32];
                        rx_wr_ptr <= rx_wr_ptr + 1;
                        rx_word_count <= rx_word_count + 1;
                        
                        if (flit_in[1:0] == `TAIL_FLIT) begin
                            receiving_packet <= 0;
                        end
                    end
                end
            endcase
        end
    end
    
    // Output assignments
    assign flit_out = flit_reg;
    assign flit_out_valid = flit_valid_reg;
    assign flit_in_ready = !receiving_packet || (rx_wr_ptr < 8);
    
    assign pkt_ready_in = (pkt_wr_ptr < 8) && !assembling_packet;
    assign pkt_data_out = rx_buffer[0]; // Simple FIFO output
    assign pkt_valid_out = (rx_word_count > 0) && !receiving_packet;

endmodule