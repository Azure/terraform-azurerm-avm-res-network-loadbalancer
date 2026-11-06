# Explicit backend members

## Selecting ownership

Pool mode is a module ownership choice, not an ARM conversion property.
NIC is the default for omission/null and has no explicit-member writer or
cleanup. Opt into `"IP"` for explicit addresses, or `"Frontend"` for Global
regional-frontend references. Native NIC and IP members require separate pools.

IP members supply `ip_address` and their VNet ID (per-member, pool or root
fallback). Frontend members supply an actual public Standard regional frontend
ID and no VNet/IP literal. Global pools require explicit Frontend mode and
compatible frontend IP families; the module validates the ID type, not all
remote resource properties.

## Dedicated endpoint lifecycle

The parent owns pool metadata and referencing rules, but omits
`loadBalancerBackendAddresses` and read-only `backendIPConfigurations`.
For each explicit pool, `local.backend_pool_members` determines one
`azapi_update_resource.backend_members` and its stateless exact-PUT action.
Before updater create/update, the action PUTs the exact desired list plus
configured pool metadata at the dedicated pool endpoint. The updater then
refreshes and writes the corrected collection.

This avoids the pinned provider's updater merge preserving unmatched old
named-array members. A parent-only write is not an authoritative explicit-member
operation. No fake identity, blanket ignore, NIC snapshot or preliminary
clear-and-restore is used. Removing the last explicit member still sends `[]`
in explicit IP/Frontend mode; removing a pool is a separate lifecycle change.

Changed explicit pools require two PUTs. The action has a fixed 30-minute
provider timeout and no configurable retry/timeouts; updater controls do not
govern it. A failure halts apply and the operations are not transactional.
Inspect a normal refreshed plan and Azure readbacks before retrying.

One `azapi_resource_action.clear_backend_members` per explicit pool stores a
fixed empty destroy request; it performs no write on creation. It clears
members before pool deletion or rename, including Global frontend references.
An updater binding replacement following parent edits replays desired members;
it is not itself an Azure pool replacement.

## Safe changes

Declare every existing explicit member before adoption. Missing configured
members are removed. Verify Azure readbacks and normal refreshed convergence
after add, subset removal, last-member clear, rename/retarget and parent updates.
Do not assume successful apply alone establishes membership persistence.

Keep existing IP pools explicitly IP, including while clearing their last
member. Before switching to NIC, clear explicit members under their existing
owner and coordinate the new NIC owner. Before switching away from NIC, detach
native NICs through that owner. Removing mode configuration is not a safe
automatic ownership transfer.

All members must satisfy Azure's shared LB/VNet and member-type restrictions.
Retargeting one IP member's VNet is not a complete LB VNet migration.
Read [Azure pool limitations](https://learn.microsoft.com/en-us/azure/load-balancer/backend-pool-management#limitations-for-ip-based-backend-pools).

Standalone pool modules are separate owners for externally managed LBs.
Do not use them alongside the root collection owner.
See [composition](child-composition.md) and [upgrade exceptions](upgrade-v0.5.0.md).
