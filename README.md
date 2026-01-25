# Network-on-Chip-Router
This project involves the design and implementation of a synthesizable Network-on-Chip (NoC) router intended for scalable multi-core System-on-Chip (SoC) architectures. The router is implemented entirely in RTL Verilog and validated using AMD Vivado through simulation and synthesis.

The NoC router supports packet-switched communication between processing elements using wormhole routing, input buffering, and credit-based flow control to prevent congestion and ensure deadlock-free operation. The design is fully parameterized to support different data widths, buffer depths, and numbers of virtual channels.

This project reflects real NoC architectures used in modern CPUs, GPUs, and AI accelerators.
