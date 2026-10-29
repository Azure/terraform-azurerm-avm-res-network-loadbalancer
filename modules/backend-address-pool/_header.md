# Backend address pool

Manages one pool, its IP-based backend addresses and Gateway tunnel interfaces.
The caller owns cardinality. NIC membership belongs to the NIC-owning module.
NIC references are omitted from writes; live preservation is not Azure-verified.
IP-based addresses are authoritative.

The root composes this module when `backend_address_pool_child_modules_enabled`
is true and no parent-owned load/outbound rule references the configured pools.
It is also independently consumable; see `examples/child-resources`.
The LB owner must preserve `properties.backendAddressPools` on every parent
update. Do not combine this module with authoritative inline ownership of the
same collection. The shared parent-ID mutex serializes child PUT/DELETE calls
within one provider process, not across Terraform states or external writers.

For adoption only, `avm_managed_migration_enabled` imports the existing named
pool into `azapi_resource.this` using this child's selected API version. The
root forwards that flag. Disable it after convergence; never use it for a new pool.
