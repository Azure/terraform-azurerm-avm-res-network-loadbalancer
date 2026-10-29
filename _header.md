# Azure load balancer — AzAPI implementation

Deploys a Standard or Gateway Azure load balancer, frontend configurations,
backend pools, IP backend members, probes, load-balancing rules, NAT rules,
outbound rules and legacy VMSS NAT pools. Supports canonical diagnostics v2,
RBAC, locks, tags, telemetry and AzAPI controls.

**Implementation status:** this is an in-progress breaking migration, not a
released or Azure-upgrade-validated implementation. The root composes writable
NAT child modules, and supports pool child modules when no parent-owned
load/outbound rule references those pools. Inline-only child types and coupled
pool/rule composition remain specification/API blockers, not approved deviations.

## ARM ownership

Frontends, probes, load-balancing rules and outbound rules have GET-only ARM
child endpoints in Network API 2025-01-01. They must be configured through the
load balancer body, not invented child PUT resources. Backend addresses and NAT
pools are also inline properties. Configured collections are authoritative;
declare all existing members before adopting this version. Do not have another
Terraform state manage the same LB collection.

NAT rules are exceptions to inline ownership: the parent sends an empty creation
placeholder and always preserves live `inboundNatRules` on updates using AzAPI's
read-before-PUT behavior. It then composes `module.inbound_nat_rule[key]`.
Set `backend_address_pool_child_modules_enabled = true` to likewise compose
`module.backend_address_pool[key]` for NAT-only or unreferenced pools. A
precondition rejects references from parent-owned load/outbound rules, including
references supplied by ID, because they would precede child creation. The
default `false` retains inline pools for those coupled cases; it does not claim
TFRMNFR1 compliance. See [composition boundaries](docs/child-composition.md).

Choose pool ownership before deployment. Adopting existing inline pools into
child mode requires the migration flag for one apply. Do not switch back:
removing a child module plans deletion of the pool, not a non-destructive handoff.
Remove referencing NAT rules in a separate apply before removing their frontend
or pool. Serialize all writers; a provider mutex does not protect another state,
and AzAPI's preservation GET occurs before acquiring that mutex.

SKU, tier and edge-zone changes retain explicit replacement triggers. Frontend
collection changes do not force replacement of the entire LB. Unlike the
released AzureRM behavior, changing a private frontend's zones is submitted as
an update: Azure may reject an unsupported change. This draft never silently
replaces the LB merely because a frontend was added or removed. Plan any actual
zone migration separately, with explicit replacement authorization.

The LB exports `backend_address_pool_resource_ids` keyed by **input map keys**.
Application owners configure memberships in the resource/module that owns the
NIC. This module has no NIC updater, association input or NIC destroy action.
Read [NIC handoff](docs/nic-membership-ownership.md).

Public IP addresses are independently owned resources, supplied by ARM ID. The
`interfaces` example demonstrates AzAPI-only public IP composition. Bundled PIP
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
   bindings, RBAC imports, and imports to `module.inbound_nat_rule[key].azapi_resource.this`.
   In child-pool mode also expect imports to
   `module.backend_address_pool[key].azapi_resource.this`. The migration flag
   uses the new input keys and preserved Azure names, not old name-keyed addresses.
   The LB body adopts the remaining inline children.
   There must be **zero unintended Azure deletes or replacements**. A forgotten
   binding is not an Azure deletion. Do not change unrelated infrastructure.
10. Apply the inspected saved plan only after independent migration review.
    Verify IDs, NIC memberships, PIP settings, assignments, locks and diagnostics;
    require convergence. Remove the migration flag and ID map, plan again, then
    test approved toggles and cleanup separately.

Details, state mapping and rollback limitations are in
[the upgrade guide](docs/upgrade-v0.5.0.md). A code revert or state restore after
Azure mutations is not a validated rollback.
