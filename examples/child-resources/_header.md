# Independently consumable child resources

Creates an AzAPI-only public load balancer, then directly consumes the pool and
NAT submodules. The parent enables child-pool mode with no inline rules or
configured pools. It preserves live child collections on subsequent PUTs.
The NAT module depends on pool creation through its resource ID.

This demonstrates standalone child consumption, not state migration proof.
The `default` example composes pools through the root; `interfaces` composes NAT
rules through the root alongside inline load/outbound rules and interfaces.
No NIC is owned here. Application owners use the pool output in their NIC module.
No outbound rule or policy exception is required for this example.
