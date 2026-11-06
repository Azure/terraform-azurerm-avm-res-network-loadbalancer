# Load balancer composition boundaries

## Root ownership

The root owns the complete LB body: frontend configurations, backend pool
metadata, probes, load-balancing rules, inbound NAT rules/pools and outbound
rules. Frontend, probe, load-balancing and outbound child endpoints in Network
API 2025-01-01 are GET-only; configure them through the parent.

Pools and NAT rules have writable child endpoints. However, parent rules need
pools to exist, while independently created pools need the parent to exist.
The root therefore creates pool skeletons and referencing rules together,
keeping pool lifecycle and metadata in the parent. It does not instantiate the
standalone pool/NAT modules. This differs from independent submodule composition;
the retained standalone modules do not make root child lifecycle independent.

Explicit IP/Frontend members use a dedicated endpoint after parent creation:
one coupled stateless exact PUT and refreshing updater per pool. Neither partial
binding creates or deletes a pool. Fixed-empty cleanup runs before pool deletion
or rename. NIC pools have no explicit-member lifecycle and default to NIC mode.
See [member behavior](ip-member-persistence.md).

## Standalone modules

`modules/backend-address-pool` and `modules/inbound-nat-rule` each manage one
named child of an externally managed LB; cardinality belongs to the caller.
The LB owner must explicitly delegate the corresponding collection and preserve
it on every parent PUT. See [child-resources](../examples/child-resources).
Never combine these owners with this root, even for different child keys.
A complete parent collection writer can erase separately managed children.

Each standalone module accepts its existing LB `parent_id`, selected API,
supported retry/timeouts and body-ignore controls. For existing-object adoption,
its own `avm_managed_migration_enabled` flag imports the named child; disable it
after convergence. This standalone contract is distinct from root upgrades,
which need no flag or pool/NAT imports.

The standalone pool defaults to NIC and omits member projections and cleanup.
Explicit IP/Frontend mode owns the complete member list and fixed-empty cleanup.
Frontend mode requires `sku_tier = "Global"` matching the real parent.

## Coordinating writes

Preserve names and configure complete collections before adoption. The shared
parent-ID mutex serializes calls in one provider process only. Freeze other
states and external writers; it is not distributed locking.

Remove references when removing a pool/NAT target. An in-place parent PUT does
not guarantee Azure accepts every child edit. Review ReadOnly locks and
selective deletion/replacement independently of full destroy.

Earlier configurations using root `module.backend_address_pool` or
`module.inbound_nat_rule` calls have nondestructive whole-call removals. Configure
their complete properties in root inputs, remove obsolete child-toggle/nested
control inputs, and inspect for forgotten bindings plus parent updates, not
child deletes or parent replacement. Inventory any forgotten telemetry objects
and assign cleanup ownership. These root-relative declarations do not retire
standalone modules elsewhere. Back up state and review that separate ownership
transfer before applying.
