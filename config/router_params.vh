// Global NoC Parameters
`define DATA_WIDTH        32
`define FLIT_WIDTH        64
`define ADDR_WIDTH        32
`define VC_NUM            4
`define BUFFER_DEPTH      8
`define PORT_NUM          5  // N, S, E, W, Local
`define NETWORK_X         4
`define NETWORK_Y         4
`define ROUTER_ID_WIDTH   4

// Flit Types
`define FLIT_TYPE_WIDTH   2
`define HEADER_FLIT       2'b00
`define BODY_FLIT         2'b01
`define TAIL_FLIT         2'b10
`define SINGLE_FLIT       2'b11

// Routing Algorithms
`define XY_ROUTING        0
`define WEST_FIRST        1
`define NORTH_LAST        2
`define ODD_EVEN          3

// Default Configuration
`define ROUTING_ALG       `XY_ROUTING
`define ARBITER_TYPE      "RR"  // Round Robin
`define FLOW_CONTROL      "CREDIT"
`define CLOCK_FREQ        100_000_000

// Packet Format
`define PKT_ID_WIDTH      8
`define DEST_X_WIDTH      4
`define DEST_Y_WIDTH      4
`define SRC_X_WIDTH       4
`define SRC_Y_WIDTH       4