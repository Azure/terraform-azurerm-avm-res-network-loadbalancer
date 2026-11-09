# Azure load balancer

Deploys a Standard or Gateway Azure load balancer with frontend configurations,
backend pools, probes, load-balancing rules, NAT rules, outbound rules and legacy
VMSS NAT pools. Supports diagnostic settings, role assignments, locks, tags,
telemetry and AzAPI controls. Public IPs and NICs are consumer-owned.

See the [default](examples/default), [complete](examples/complete),
[multi-region](examples/multi-region) and [standalone child](examples/child-resources)
examples. Use Terraform >=1.16 and <2.0 with the provider versions declared by
the module; its interfaces dependency requires AzAPI >=2.13.

## Backend membership

`backend_address_pools` is keyed by stable consumer keys. The exported
`backend_address_pool_resource_ids` uses those same keys.

- **NIC is the default**, including an omitted or null `backend_address_type`.
  The module manages pool metadata but never writes NIC membership or replays
  its read-only projection. There is no explicit-member writer or cleanup for
  NIC pools. Pass the pool IDs to the resource/module owning the NIC.
- **IP is opt-in**: set `backend_address_type = "IP"` and configure
  `backend_address_pool_addresses`. This list is authoritative, including an
  empty list to remove the last member.
- **Frontend is explicit** for Global pools. Each member references an actual
  regional LB frontend through
  `load_balancer_frontend_ip_configuration_resource_id`, not an IP literal.
  Use public Standard regional frontends with compatible IP families.
  Global pools cannot have VNet/tunnel settings. Global rules use one pool,
  matching frontend/backend ports and no TCP reset, probes, NAT or outbound rules.

IP and native NIC members require separate pools, although both kinds can
coexist on one LB:

```hcl
backend_address_pools = {
  static = { name = "static", backend_address_type = "IP" }
  nvas   = { name = "nvas" }
}
```

Point explicit addresses at `"static"`; pass the `"nvas"` pool ID to the NIC
owner. Input validation reports explicit addresses targeting NIC pools. It
cannot validate attachments made by another state; the NIC owner must not
attach native NICs to IP pools.

Modes declare ownership, **not an Azure conversion**. Keep populated IP pools
explicitly IP. Clear explicit members before a separately coordinated switch to
NIC; detach native NICs through their owner before switching away from NIC.
Do not switch modes to bypass validation.
See [NIC ownership](docs/nic-membership-ownership.md) and
[explicit-member behavior](docs/ip-member-persistence.md).

## Ownership and updates

The parent LB owns complete frontend, pool metadata, probe, rule, NAT and
outbound collections. It omits member lists and read-only NIC back-references.
Dedicated pool endpoints manage explicit IP/Frontend members through one
coupled exact-PUT action and refreshing updater. Changed explicit pools require
two PUTs; these are not transactional. The stateless action has a fixed
30-minute timeout and no configurable retry/timeouts. Fixed-empty destroy
actions clear explicit members before pool deletion or rename.

Do not combine this root with standalone child modules or another writer to
the same LB collections. Standalone pool/NAT modules are for externally managed
LBs whose owner delegates those collections and preserves them on every parent
write. The root deliberately keeps pool lifecycle with referencing parent rules
to avoid creation cycles; this is a practical composition boundary, not full
independent-submodule composition. See [composition](docs/child-composition.md).

Configured collections are authoritative. Declare all existing objects before
adoption and remove references when removing a target. Null means unspecified,
not a request to clear a server value; empty managed lists express removal.
Map/reference ordering is normalized for stable requests.

AzAPI replaces on name, parent scope and location changes; SKU, tier and edge
zone also have replacement controls. Frontend edits, including private zones,
are submitted as updates, not automatic LB replacement; Azure may reject
unsupported changes. An in-place plan is not a zero-disruption guarantee.
Review zone migrations and other immutable changes separately.

`resource_types` overrides selected APIs. `retry` and `timeouts` configure
supported managed resources, not the stateless action. `ignore_body_changes`
uses body-relative dot paths; ignored configuration is not sent to Azure and
changes take effect only after apply. Do not use ignores to mask convergence
defects. Diagnostic omitted/null/empty entry sets are unspecified; use explicit
category/group/enabled values for managed entries.

Freeze competing writers during adoption. The parent-ID mutex serializes
operations within one provider process, not across states. Remove ReadOnly
locks before updates and deletion-blocking locks before selective replacement.
The full-destroy lock-removal wait is not an update-time unlock.

## Upgrading from v0.5.0

See the [upgrade guide](docs/upgrade-v0.5.0.md) for address mapping and exceptions.

1. Back up protected state and inventory existing names, IDs, properties,
   memberships, assignment GUIDs and extension settings. Keep the released
   AzureRM provider configuration available until state conversion completes.
2. Replace `resource_group_name` with the existing resource group's `parent_id`.
   Keep LB identity, SKU/tier, edge zone, frontend/child names and input keys.
3. Preserve every explicit IP member and set its pool to `"IP"`. Native NIC
   pools use the NIC default without a new input or explicit-member writes.
4. Move PIP creation and its locks, diagnostics and RBAC to a consumer owner
   using captured IDs/names/settings. Pass `public_ip_address_resource_id`.
   Inspect imports for case-only parent-ID replacement before applying.
5. Update diagnostics to canonical `logs`/`metrics` objects, preserving names
   and destinations. Review output consumers: discrete ID maps remain keyed
   by input keys. Replace removed whole-resource outputs with `resource_id`,
   `name` and the discrete child-ID maps; AzureRM object shapes are not emulated.
6. Configure complete memberships in the NIC owner, then retire
   `backend_address_pool_network_interfaces`. Module-owned nondestructive
   removals forget legacy association bindings without detaching NICs.
7. Review a saved plan. Module-owned moves preserve LB, lock, diagnostics and
   ordinary RBAC identities at the same boundary/key map. RBAC moves preserve
   native GUIDs without caller imports or a migration flag. Only legacy
   delegated assignments with composite `ARM-ID|tenant` state IDs require the
   narrow per-key import exception in the guide.
8. Reject unintended deletion/replacement or lost membership. Apply only the
   inspected plan, verify independent readbacks and normal refreshed no-op
   plans. A code revert/state restore is not an automatic post-apply rollback.

For older pre-release configurations that relied on the former IP default,
explicitly pin existing IP pools to `"IP"` **before** upgrading. Do not let the
new default silently change ownership. Erroneous explicit-member bindings on
native NIC pools require the selective recovery described in the guide; never
send an empty IP list against native NIC references.
