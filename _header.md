# Azure load balancer — AzAPI implementation

Deploys a Standard or Gateway Azure load balancer, frontend configurations,
backend pools, IP and regional-frontend backend members, probes, load-balancing rules, NAT rules,
outbound rules and legacy VMSS NAT pools. Supports canonical diagnostics v2,
RBAC, locks, tags, telemetry and AzAPI controls.

**Implementation status:** this is an unreleased breaking migration candidate.
Independent Azure verification of
`7ebb9465497dbae051d4d8ca45aeca718e86c01b` passed the multi-region example,
core member/pool lifecycle and a qualified same-state upgrade from v0.5.0.
The parent owns pool metadata and
referencing rules; a coupled exact-PUT action and refreshing dedicated-endpoint
updater exclusively manage each explicit member list. Fixed-empty destroy actions clear those lists before
pool removal. These scoped results do not establish full AVM specification
compliance or unconditional release readiness. See the tested scope and
remaining limits below.

## ARM ownership

Frontends, probes, load-balancing rules and outbound rules have GET-only ARM
child endpoints in Network API 2025-01-01. They must be configured through the
load balancer body, not invented child PUT resources. Pools and NAT rules do
have writable endpoints, but splitting out pool lifecycle leaves parent rules
needing pools before those separate children can exist. The parent therefore
bootstraps and owns pool skeletons/metadata alongside rules. It never sends
`loadBalancerBackendAddresses` or read-only `backendIPConfigurations`.
A single `azapi_update_resource.backend_members[pool_key]` refreshes the explicit
member list. Its `before_create` / `before_update` stateless
`action.azapi_resource_action.write_backend_members[pool_key]` first PUTs the
exact desired list at the dedicated endpoint, together with the root's configured
pool metadata. The updater then reads/writes that already-correct collection.
These are one coupled partial-field lifecycle, not independently applied writers.
Neither creates or deletes a pool. Pool metadata remains sourced from the parent.

All configured collections are authoritative, including empty lists for removal,
with explicit member lists owned separately (see below).
Declare every existing member before adoption. Do not combine this root with
standalone child modules or another writer for the same LB collections. Retained
pool/NAT modules are independently useful only for externally managed LBs whose
owners explicitly delegate those collections. See
[composition boundaries and specification departure](docs/child-composition.md).

## Plan stability and updates

An unchanged complete body does not inherently cause delete/create. Maps are
iterated deterministically by key, unordered reference lists and zone lists are
sorted, and request bodies omit read-only back-references. Null optional values
are omitted on the wire (`ignore_null_property = true`); empty lists are still
sent. Use explicit supported values to reset a default: null means unspecified,
not "clear the server value". There are no default collection ignore paths hiding
managed edits. Consumer-selected ignore paths disable writes at those paths and
must not be used to mask convergence defects.

SKU, tier and edge-zone changes retain explicit replacement triggers. Frontend
collection changes do not force replacement of the entire LB. Unlike the
released AzureRM behavior, changing a private frontend's zones is submitted as
an update: Azure may reject an unsupported change. This draft never silently
replaces the LB merely because a frontend was added or removed. Plan any actual
zone migration separately, with explicit replacement authorization. AzAPI also
replaces on name, parent scope and normalized location changes. SKU/tier body
paths and a stable external SKU/tier/edge-zone object cover deliberate immutable
changes, including edge-zone null transitions.

Mutable child edits normally plan as an in-place `~` on the LB and can send a
parent PUT, not a child-level PATCH. That is not a service zero-disruption
guarantee; Azure may reject immutable child-property changes. Mocked request
equality is not proof of refresh normalization or repeat no-op plans. Those
require an authorized real apply, repeat full-refresh plan, mutable-update apply,
clean follow-up plan, and state-backed upgrade test. On exact candidate
`7ebb946`, independent Azure tests passed fresh multi-region deployment,
16 core member/parent/NIC/pool-lifecycle cases and a same-state v0.5.0 upgrade,
with 40 normal refreshed no-op plans across the run. Historical failed
convergence and removal tests remain failures of their original candidates.
Telemetry was disabled. Deliberate LB replacement, standalone Frontend-pool
destruction, enabled telemetry and traffic/failover remain unproved.
Freeze other writers during adoption/updates. Remove applicable ReadOnly locks
before updates and locks preventing deletion before selective destructive
operations; the full-destroy lock barrier is not an update-time unlock mechanism.

The LB exports `backend_address_pool_resource_ids` keyed by **input map keys**.
Application owners configure memberships in the resource/module that owns the
NIC. This module has no NIC updater, association input or NIC destroy action.
Read [NIC handoff](docs/nic-membership-ownership.md).

### IP and NIC members require separate pools

Azure allows IP-based and NIC-based pools on the same load balancer, but rejects
mixing explicit IP members and native NIC associations in a single pool with
`CannotMixIPBasedAddressesAndIPConfigurationsOnLoadBalancerBackendAddressPool`.
Configure distinct pools, for example:

```hcl
backend_address_pools = {
  static = { name = "static", backend_address_type = "IP" }
  nvas   = { name = "nvas", backend_address_type = "NIC" }
}
```

Point `backend_address_pool_addresses[*].backend_address_pool_object_name` at
`"static"`. Pass `backend_address_pool_resource_ids["nvas"]` to the NIC-owning
module for native membership. The module rejects IP members targeting NIC-mode
pools and reports the conflicting address and pool input keys.

Validation covers this module's inputs, not associations managed by another
module or state. The NIC owner must not attach NICs to an IP-based pool; Azure
enforces that external operation. Setting `backend_address_type` does not convert
an existing pool or move its members. Coordinate migration separately rather
than changing the mode to bypass validation. See
[Azure's pool membership limitations](https://learn.microsoft.com/en-us/azure/load-balancer/backend-pool-management#limitations-for-ip-based-backend-pools).

Set `backend_address_type = "NIC"` on each NIC-based pool. Its
`loadBalancerBackendAddresses` is absent from the parent and has no updater:
Azure returns NIC-derived entries with read-only NIC references and NAT port
mappings there. They are not desired IP members and must not be replayed or
compared with an explicit empty IP-member list. The pool itself, its name,
tunnels and other configured properties remain managed. NIC membership remains
exclusively with the NIC owner; this does not adopt external IP members.

`backend_address_type = "IP"` is the default. The desired member list is sent
only through the dedicated endpoint and compared on refresh, with missing
properties not ignored. The updater alone merges named arrays and retains
removed entries, so the stateless pre-write action is mandatory; it sends the
desired list without reading/merging an old member list. No identity-key
fallback, ignored drift or clear-all-before-repopulate sequence is used.
The action halts apply on failure. Removing the last member sends `[]`. Parent changes
recreate only the updater's partial Terraform binding and replay the desired
list after the parent write; the updater's destroy itself performs no operation.
A separate `azapi_resource_action.clear_backend_members[pool_key]` stores only
a fixed empty list for destroy. Its dependency on the updater orders clearing
before inline pool removal/rename or parent replacement/destruction; regional
frontend dependencies also protect teardown of referenced regional LBs.
The lock-removal barrier covers both resources. Remove ReadOnly locks for
updates and applicable locks for selective removal; the barrier does not unlock
ordinary updates automatically.

The earlier parent-list implementation failed live IP persistence.
Candidate `ab278cc` passed fresh multi-region deployment, repeated refreshed
no-ops, parent/NIC updates and ordinary automatic destroy, but **failed removal
of one Global frontend member**: the updater sent both old members despite an
east-only plan. Its cleanup passed; its migration test was stopped.
Independent Azure verification of correction `7ebb946` subsequently passed
IP/frontend subset removal, last-member clear/restore, rename/retarget and drift
reconciliation. Serialized requests confirmed the exact action PUT preceded
updater reads/writes, without preliminary clearing of retained members.
Pool removal with its rule, recreation, rename and ordinary automatic destroy
also passed. These are new exact-candidate results, not relabeled diagnostic
or `ab278cc` passes. The same-state upgrade passed with the import-ID casing
qualification described below. See
[IP-member persistence investigation](docs/ip-member-persistence.md).
IP members on a NIC-mode pool are rejected.
Omitted or null mode values default to IP; an empty IP-member map never selects
NIC mode implicitly. To change pool modes, clear IP members while still in IP
mode and verify readback before separately coordinating the NIC owner. Detach
native NICs through their owner before switching from NIC to IP mode. Changing
to NIC mode removes the explicit owner and executes its fixed-empty cleanup;
do not use mode changes as a substitute for an inspected membership migration.

### Global multi-region pools

Set `sku_tier = "Global"`, `sku = "Standard"` and
`backend_address_type = "Frontend"` for Global pools. Each
`backend_address_pool_addresses` entry requires
`load_balancer_frontend_ip_configuration_resource_id`, mutually exclusive with
`ip_address` and VNet configuration. References must identify actual public
Standard regional LB frontends; ID parsing validates type, not remote tier,
publicness or IP-family compatibility. The consumer must ensure those match.
Global pools cannot use IP/NIC mode, VNet metadata or tunnels.

Global LBs allow public frontends and load-balancing rules, not configured
health probes (including rule probe IDs), outbound rules or NAT pools/rules.
Health is inherited from regional LBs. Global rules require matching frontend/backend ports,
TCP reset disabled, and exactly one pool reference; this is serialized using
the singular `backendAddressPool` field exercised by both the corrected
diagnostic and exact-candidate `7ebb946` deployment and rule-update tests.
Deploy Global LB/PIP resources in a supported home region and use matching IP families across tiers;
the module does not hard-code a changing Azure home-region catalog.
See [multi-region](examples/multi-region) for two regional LBs and a Global
LB, separate regional IP/NIC pools and real frontend-reference members.
It has no VMs or traffic/health proof.

Public IP addresses are independently owned resources, supplied by ARM ID. The
`complete` example demonstrates AzAPI-only public IP composition. Bundled PIP
creation is retired rather than embedding a second resource module inside the
LB resource module. Adopt existing PIPs and their extension resources without
deleting them; see the upgrade guide.

## Optional interface and control semantics

Diagnostics use the canonical interfaces utility v2 contract. Omitted, null and
empty `logs`/`metrics` sets become null body properties, **not explicit ARM empty
arrays**. Null fields are omitted on PUT and are unspecified during refresh,
including Azure-expanded disabled log categories. Do not rely on these values
to clear existing log/metric entries: use explicit `enabled = false` entries.
Non-null category/group entries, enabled/retention values and destinations
remain compared; logs match by category plus categoryGroup and metrics by
category, not array order. There is no blanket log ignore.
Removing a diagnostic setting's map key removes the entire Terraform resource;
changing entries or destinations still requires service-side convergence proof.
Marketplace partner IDs are polymorphic; workspace, storage and Event Hub rule
IDs are validated against their respective ARM types.

Keep `retry = null` to use provider defaults. When supplying a retry object,
include `error_message_regex`: AzAPI requires it even though the canonical
interface declares the field optional. Unspecified retry intervals are
provider-computed; unspecified timeout operations use provider defaults.
Each full resource has an independent API-version and ignore-path slot.
The dedicated member updater and destroy action share the pool API-version
slot, retry and timeouts. Pinned AzAPI does not expose `ignore_body_changes`
for these two resource kinds; no unsupported argument or blanket ignore is
invented. The cleanup request in AzAPI 2.13 uses the **create** timeout even at
destroy; set that timeout for clearing rather than relying on `delete` alone.
The stateless pre-write action uses the same pool API version and parent mutex,
but AzAPI 2.13 exposes **no retry/timeouts or response-export arguments** on
stateless actions and fixes their timeout at 30 minutes. Resource retry/timeouts
therefore do not govern that first PUT. A changed explicit pool normally issues
two PUTs (exact action, then refreshing updater), with no preliminary empty-list
write. ReadOnly locks must be removed before either write.
The existing Terraform >=1.16 requirement supports action triggers; the root's
pinned interfaces utility already imposes AzAPI >=2.13. No new provider is added.
An older API override must support every configured property; schema validation
is not disabled to make an incompatible version pass.

Only the LB offers tags here; there is no per-resource tag override interface.
`tags = null` is unspecified, while `{}` is an explicit empty desired tag map.
Mocks do not prove Azure tag clearing or provider-private ignore behavior.

## Breaking upgrade from v0.5.0

The tested source baseline is v0.5.0, commit
`e83d34778efeb54a1779b968106067cc4b2bad63`.
The independent same-state upgrade to `7ebb946` passed after a recorded
consumer import-ID casing correction: 5 imports, 3 moves, 15 nondestructive
forgets, 5 state/binding additions, 8 updates and zero deletes/replacements.
The initial case-only diagnostic replacement plan was rejected before apply;
after asserting case-insensitive identity equality, the import ID was
canonicalized to the already-declared PIP parent plus captured diagnostic name.
A separately inspected zero-replacement plan was applied. Do not blindly copy
returned import-ID casing or accept a replacement as harmless.
Identity/interface checks, two migration no-ops, migration-flag removal, a real
NIC-owner update and cleanup passed. This remains an unreleased candidate,
not blanket production or rollback approval.

1. Use Terraform `>= 1.16, < 2.0` and AzAPI `~> 2.12`. Keep an AzureRM provider
   configured at the consumer root until all released state has been converted.
2. Replace `resource_group_name` with the full existing resource group
   `parent_id`. Keep the same subscription, region, LB name, SKU, tier and edge
   zone. Preserve all resolved frontend, pool, probe, rule and NAT names.
3. Replace whole-resource outputs (`resource`, `azurerm_lb`,
   `azurerm_lb_backend_address_pool`, `azurerm_lb_nat_rule`, `azurerm_public_ip`)
   with the discrete ID maps and `name`. Whole-resource object shapes are not
   compatible with AzAPI and are intentionally not emulated.
4. Replace legacy diagnostic `log_categories`, `log_groups`, `metric_categories`
   with canonical `logs` and `metrics` objects. Preserve actual existing
   diagnostic names (`diag-<LB name>` by default). Category/group distinction and
   `event_hub_name` now work correctly; these are intentional bug fixes, not
   proof that enabling previously ignored settings is state-neutral.
5. Inventory legacy PIP names/IDs/settings and extension resources, and
   prepare their new consumer-owned configurations. Pass their actual existing
   IDs as `public_ip_address_resource_id`, including cross-scope IDs. Remove
   `create_public_ip_address`, `public_ip_address_configuration`, PIP inheritance
   and PIP extension settings from the LB inputs. Nothing creates replacement
   PIPs automatically.
6. Remove `backend_address_pool_network_interfaces` from LB configuration.
   Record all live NIC memberships and prepare the NIC owner's complete desired
   membership lists. Legacy association and PIP bindings are forgotten with
   module-owned `removed { lifecycle { destroy = false } }`; they are not
   detached/deleted. Follow the coordinated ownership handoff before either
   state next writes those properties.
7. Remove any `ReadOnly` lock before conversion. Preserve `CanNotDelete` lock
   names: the released LB default is `lock-<LB name>`, **not** `lock-CanNotDelete`.
   The released PIP lock default is `lock-<public_ip_address_resource_name>`.
   Capture the actual lock IDs; never infer or rename them during adoption.
8. Capture existing assignment GUIDs and supply
   `migration_role_assignment_resource_ids`, keyed like `role_assignments`.
   Set `avm_managed_migration_enabled = true` for the one migration apply.
   Strip any legacy `|<tenant>` suffix from import IDs. Existing GUIDs are
   imported and ignored for subsequent generated-name changes. Do not create
   replacement assignments under a lock.
9. Save and inspect a migration plan. Expect a same-boundary LB provider move,
   lock/diagnostic provider moves, forgotten synthetic child/association/PIP
   bindings and captured-GUID RBAC imports. The LB body adopts **all** configured
   child metadata and rules; dedicated member updater bindings apply to existing
   pool endpoints without a second pool import or Azure pool creation. Cleanup
   actions only store their empty destroy request on creation. There are no
   root pool/NAT module imports. Released child
   bindings are forgotten with `destroy=false`, never destroyed. Experimental
   drafts with root-composed children also have non-destructive module removals;
   see the distinct draft-to-draft procedure in the upgrade guide.
   There must be **zero unintended Azure deletes or replacements**. A forgotten
   binding is not an Azure deletion. Do not change unrelated infrastructure.
10. Apply the inspected saved plan only after independent migration review.
    Verify IDs, NIC memberships, PIP settings, assignments, locks and diagnostics;
    require convergence. Remove the migration flag and ID map, plan again, then
    test approved toggles and cleanup separately.

Details, state mapping and rollback limitations are in
[the upgrade guide](docs/upgrade-v0.5.0.md). A code revert or state restore after
Azure mutations is not a validated rollback.
