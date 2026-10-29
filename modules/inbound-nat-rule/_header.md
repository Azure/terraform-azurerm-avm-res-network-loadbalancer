# Inbound NAT rule

This standalone module is for externally managed LBs only; see
`examples/child-resources`. The root does not call it and always owns the entire
NAT rule collection. Never use both owners on the same LB, even for different keys.
The external LB owner must
preserve `properties.inboundNatRules` on parent updates, rather than sending an
authoritative inline list. The shared parent-ID mutex serializes child writes
within one provider process, not across states or external writers.

Manages one v1 scalar-port or v2 backend-pool port-range NAT rule.
The calling module owns cardinality and reference ordering.

For adoption only, `avm_managed_migration_enabled` imports the existing named
rule into `azapi_resource.this` using this child's selected API version. The
standalone caller sets that flag. Disable it after convergence; never use it for a new rule.
