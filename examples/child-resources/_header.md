# Independently consumable child resources

Creates an externally managed AzAPI public load balancer, then directly consumes
the pool and NAT submodules. **It does not use this repository's root module.**
The external LB owner explicitly delegates these two collections and preserves
them on parent updates. This is a separate ownership model for standalone use,
not an option offered by the authoritative root.
The NAT module depends on pool creation through its resource ID.

This demonstrates standalone child consumption, not state migration proof.
The `default` and `interfaces` examples manage all their child collections in
the root LB body. Never combine these standalone modules with root ownership of
the same collections, even when the root collections are initially empty.
No NIC is owned here. Application owners use the pool output in their NIC module.
No outbound rule or policy exception is required for this example.
