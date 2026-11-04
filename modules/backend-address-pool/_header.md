# Backend address pool

Manages one pool, explicit IP or regional-frontend backend addresses, and Gateway tunnel interfaces.
The caller owns cardinality. NIC membership belongs to the NIC-owning module.
Set `backend_address_type = "NIC"` to omit the server-maintained address
projection; native NIC references are never authored here. IP/Frontend member
lists are authoritative, including `[]` for last-member removal. Frontend mode
requires the caller to declare `sku_tier = "Global"` matching the actual parent.
Each frontend member supplies `properties.loadBalancerFrontendIPConfiguration.id`
instead of `properties.ipAddress`, with no VNet. IDs must reference public
Standard regional LB frontends of a compatible IP family; this module validates
the ARM type, not the remote resource's configuration.

One destroy-only action clears the explicit list before pool deletion or rename,
required for Global frontend-reference pools. It stores a fixed empty list,
not a NIC snapshot, and is not the refreshing resource owner. It shares retry,
timeouts and the parent mutex. AzAPI 2.13 does not support ignore_body_changes
on actions, and its destroy action uses the create timeout for the request.
Exact-candidate automatic lifecycle and migration remain subject to live proof.

This standalone module is for externally managed LBs only; see
`examples/child-resources`. The root does not call it and always owns the entire
pool collection. Never use both owners on the same LB, even for different keys.
The LB owner must preserve `properties.backendAddressPools` on every parent
update. Do not combine this module with authoritative inline ownership of the
same collection. The shared parent-ID mutex serializes child PUT/DELETE calls
within one provider process, not across Terraform states or external writers.

For adoption only, `avm_managed_migration_enabled` imports the existing named
pool into `azapi_resource.this` using this child's selected API version. The
standalone caller sets that flag. Disable it after convergence; never use it for a new pool.
