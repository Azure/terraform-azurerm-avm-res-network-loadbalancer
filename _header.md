# Azure load balancer — AzAPI implementation

Deploys a Standard or Gateway Azure load balancer, frontend configurations,
backend pools, IP backend members, probes, load-balancing rules, NAT rules,
outbound rules and legacy VMSS NAT pools. Supports canonical diagnostics v2,
RBAC, locks, tags, telemetry and AzAPI controls.

**Implementation status:** this is a breaking migration draft, not a released
or Azure-upgrade-validated implementation. All LB child collections, including
backend pools and inbound NAT rules, are managed in one authoritative parent
body. This is the selected practical REST-aligned design, not a pending ownership
choice or a claim of full AVM specification compliance.

## ARM ownership

Frontends, probes, load-balancing rules and outbound rules have GET-only ARM
child endpoints in Network API 2025-01-01. They must be configured through the
load balancer body, not invented child PUT resources. Pools and NAT rules do
have writable endpoints, but splitting them out leaves parent rules needing
pools before those separate children can exist. One complete LB write avoids
that dependency cycle and competing writes. No object-only submodules are used.

All configured collections are authoritative, including empty lists for removal.
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
clean follow-up plan, and state-backed upgrade test. Live convergence is unproven.
Freeze other writers during adoption/updates. Remove applicable ReadOnly locks
before updates and locks preventing deletion before selective destructive
operations; the full-destroy lock barrier is not an update-time unlock mechanism.

The LB exports `backend_address_pool_resource_ids` keyed by **input map keys**.
Application owners configure memberships in the resource/module that owns the
NIC. This module has no NIC updater, association input or NIC destroy action.
Read [NIC handoff](docs/nic-membership-ownership.md).

Public IP addresses are independently owned resources, supplied by ARM ID. The
`complete` example demonstrates AzAPI-only public IP composition. Bundled PIP
creation is retired rather than embedding a second resource module inside the
LB resource module. Adopt existing PIPs and their extension resources without
deleting them; see the upgrade guide.

## Breaking upgrade from v0.5.0

The supported source baseline under investigation is v0.5.0, commit
`e83d34778efeb54a1779b968106067cc4b2bad63`.
**Real-Azure upgrade validation has not run. Do not apply this draft to production.**

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
   child collections; there are no root pool/NAT module imports. Released child
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
