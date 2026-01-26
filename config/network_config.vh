// Network Configuration
`ifndef _NETWORK_CONFIG_VH
`define _NETWORK_CONFIG_VH

// Traffic Patterns
typedef enum logic [2:0] {
    UNIFORM = 3'b000,
    BIT_REV = 3'b001,
    TRANSPOSE = 3'b010,
    HOTSPOT = 3'b011,
    SHUFFLE = 3'b100
} traffic_pattern_t;

// Router States
typedef enum logic [1:0] {
    ROUTER_IDLE = 2'b00,
    ROUTER_BUSY = 2'b01,
    ROUTER_CONGESTED = 2'b10,
    ROUTER_ERROR = 2'b11
} router_state_t;

// Link Status
typedef struct packed {
    logic valid;
    logic ready;
    logic error;
    logic [VC_NUM-1:0] vc_available;
} link_status_t;

// Performance Counters
typedef struct packed {
    logic [31:0] flits_received;
    logic [31:0] flits_sent;
    logic [31:0] packets_received;
    logic [31:0] packets_sent;
    logic [31:0] congestion_count;
    logic [31:0] latency_sum;
} perf_counters_t;

`endif