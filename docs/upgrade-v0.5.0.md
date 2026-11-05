# v0.5.0 to AzAPI — draft upgrade procedure

**Unreleased candidate with qualified upgrade proof.** Independent Azure testing
applied v0.5.0 and upgraded the same state to
`7ebb9465497dbae051d4d8ca45aeca718e86c01b`, preserving identities and interfaces,
reaching refreshed no-op plans and completing a real NIC-owner write and cleanup.
The first consumer PIP diagnostic import plan proposed a case-only replacement
and was rejected before apply; the successful separately inspected plan required
the import-ID casing correction described below. Earlier failed convergence
remains historical evidence, not a pass. These scoped results do not establish
unconditional production readiness, full interface coverage or rollback safety.
The approved design manages **pool metadata and referencing rules in the parent
body**, with explicit IP/frontend lists managed by coupled exact-PUT actions
and refreshing dedicated-pool endpoint updaters. The parent never sends member lists. This avoids the
parent-rule/separate-pool bootstrap cycle without a second pool lifecycle
resource. Fixed-empty destroy actions clear explicit lists before removal.
There is no root ownership
switch or object-only submodule. This practical design deliberately departs
from current TFRMNFR1 composition requirements; full compliance is not claimed.

## Baseline and target

- Released baseline: v0.5.0,
  `e83d34778efeb54a1779b968106067cc4b2bad63`.
- Tested target: `7ebb9465497dbae051d4d8ca45aeca718e86c01b`.
  Documentation-only descendants retain this runtime evidence only if
  runtime, dependency and migration sources are unchanged; they are not new
  live-tested SHAs.
- Terraform >=1.16 and <2.0; Azure/azapi ~>2.12.
- Canonical interfaces utility: `Azure/avm-utl-interfaces/azure` **0.9.0**.
- Keep the released AzureRM provider configuration in the consumer until the
  conversion apply has removed all AzureRM state bindings.

## State and ownership mapping

All addresses below are relative to the existing LB module. For a nested keyed
consumer, prefix them with e.g.
`module.workload["app"].module.load_balancer.`. No wildcard resource-to-module
move is claimed.

| Released address / inline member | Draft owner / mechanism |
|---|---|
| `azurerm_lb.this` | `azapi_resource.this`, same-boundary provider `moved` |
| LB inline frontend configurations | LB body's `frontendIPConfigurations`, preserved names |
| `azurerm_lb_backend_address_pool.this[key]` | LB body's `backendAddressPools`; old binding forgotten with `destroy=false`, no ARM delete |
| `azurerm_lb_backend_address_pool_address.this[key]` | `azapi_update_resource.backend_members[pool_key]` owns the dedicated endpoint list; synthetic binding forgotten |
| `azurerm_lb_probe.this[key]` | LB body's `probes`; old binding forgotten |
| `azurerm_lb_rule.this[key]` | LB body's `loadBalancingRules`; old binding forgotten |
| `azurerm_lb_nat_rule.this[name]` | LB body's `inboundNatRules`, preserving Azure name; old binding forgotten with `destroy=false` |
| `azurerm_lb_outbound_rule.this[name]` | LB body's `outboundRules`; old binding forgotten |
| `azurerm_lb_nat_pool.this[name]` | LB body's `inboundNatPools`; old binding forgotten |
| `azurerm_network_interface_backend_address_pool_association.this[key]` | NIC owner; forgotten with destroy=false, no NIC action |
| `azurerm_management_lock.this[0]` | `azapi_resource.lock[0]`, same-boundary provider move |
| `azurerm_monitor_diagnostic_setting.this[key]` | `azapi_resource.diagnostic_settings[key]`, provider move; AzAPI explicitly converts target-ID/name composite IDs |
| `azurerm_role_assignment.this[key]` | `azapi_resource.role_assignments[key]`, forgotten + gated import using captured actual GUID |
| `azurerm_public_ip.this[key]` | consumer PIP owner; forgotten, independently import actual existing ID |
| `azurerm_management_lock.pip[key]` | consumer PIP lock owner; forgotten, import actual existing ID/name |
| `azurerm_monitor_diagnostic_setting.pip[frontend-ds]` | consumer PIP diagnostic owner; forgotten, import actual ARM extension ID |
| `azurerm_role_assignment.pip[frontend-role]` | consumer PIP RBAC owner; forgotten, import actual GUID/scope |
| released modtm/random telemetry | pre-existing HEAD migration statements; not introduced by this implementation |

Pool IP addresses are authoritative. Inventory and configure all live IP-based
members before conversion. Set `backend_address_type = "NIC"` on every
NIC-based pool (`app` and `retained` in the migration fixture); keep IP-based
pools in the default `"IP"` mode even when removing their last IP member.
NIC mode omits the server-maintained address projection, not the pool itself,
and rejects configured IP members. Never switch modes as an implicit deletion.
NIC-based membership is not written by this module.
Preservation during the exercised parent/NIC PUTs passed exact-candidate
state-backed verification on `7ebb946`; new writer combinations still need
their own proof.
Every configured collection is authoritative, including pools and NAT rules.
Reconcile all live members before using this draft. Read-only NIC back-references
are excluded from the request; that implementation detail alone is not
preservation proof.

## Released child adoption and ordering

Set `avm_managed_migration_enabled = true` for the one upgrade apply. The module
forgets released child bindings without deletion. The moved/imported LB adopts
their configured metadata and rules in its body; no pool/NAT imports target root
child modules. The migration flag gates captured-ID RBAC imports only. Never
enable it on an empty deployment with role assignments: imports need existing
objects. No generic collection-to-module `moved` block is claimed.

New `azapi_update_resource.backend_members[pool_key]` bindings do not import or
create a second pool. Their initial apply writes the existing dedicated endpoint
after the parent has adopted/created metadata. A stateless `before_create` /
`before_update` action first sends the exact desired list, avoiding the pinned
updater's named-array append behavior. The updater then observes/replays the
corrected pool. The action has no state/import and creates no second lifecycle
owner. Existing updater and cleanup addresses are unchanged from `ab278cc`;
no new move/removed block is needed for this correction. The provider forgets these partial
bindings without deleting anything. One `clear_backend_members[pool_key]`
destroy action stores a fixed empty list on initial creation; no Azure call occurs
then. No migration import is required for these partial updaters/actions.
On parent edits the updater binding is replaced and replays its desired list;
such a binding replacement is not an Azure pool replacement. Inspect the actual
plan to distinguish them. Existing IP members must all be declared, or this
authoritative write can remove omitted members.

The action uses the existing Terraform >=1.16 language surface and effective
AzAPI >=2.13 root dependency. It shares the pool API override and mutex but
has a fixed 30-minute provider timeout and no configurable retry/timeouts.
Do not assume the updater's retry controls govern the action. Two PUTs per
changed explicit pool are expected; there is no clear-all-before-restore stage.
Candidate `ab278cc` passed fresh deployment/ordinary cleanup but failed
nonempty frontend removal, and its migration was not started. Those results
remain scoped to that SHA. Correction `7ebb946` subsequently passed independently
applied v0.5.0-to-exact-candidate upgrade and ordinary automatic destroy.
The executed nested consumer plan contained 5 imports, 3 moves, 15 nondestructive
forgets, 5 state/binding additions, 8 updates and zero deletes/replacements.
Full ARM comparisons covered LB/PIP/NIC identities, native memberships,
children/rules, diagnostics, role GUIDs and locks. Two immediate migration
no-ops, migration-flag removal and an actual NIC-owner PUT with the complete
two-pool list passed. All fixture states were empty and test RGs absent after
cleanup. No VMs were deployed and telemetry was disabled.

The nested parent destination is
`module.workload["app"].module.load_balancer.azapi_resource.this`.
Released NAT/pool addresses remain in the `removed { destroy = false }`
declarations at that same LB module boundary. Stable input keys are not a
substitute for preserving each resolved Azure child name.

The lock removal barrier covers the parent, diagnostics, RBAC, member updaters
and cleanup actions. Full destroy removes the lock, waits, clears explicit
member lists and then deletes the parent and its child collections.
Selective updates under ReadOnly locks, and removals subject to applicable locks,
need separately reviewed unlocking. Parent updates are complete PUTs, not an
assurance that Azure permits every child edit or preserves every live relationship.
Freeze cross-state writers and verify readback. A provider mutex is not a
distributed lock. Remove references when removing their target from the body;
test simultaneous collection changes in the isolated lab before production use.

## Experimental child-composition draft to current draft

This is **not** the released v0.5.0 path. Earlier unreleased drafts, including
`96ca5f9ee924133b4f91ac4da8781bc30bfc8571`, called
`module.backend_address_pool[key]` and `module.inbound_nat_rule[key]` in the root.
The current module includes whole-call `removed` blocks with `destroy=false` for
those two addresses. They forget all instances (including any draft telemetry
bindings) without sending child DELETEs. The parent then adopts the complete
configured collections. This procedure is implemented but not applied-state
verified; do not assume ordinary removal of a module is harmless.

Back up state and inventory names, properties, NIC memberships and telemetry
deployments. Remove `backend_address_pool_child_modules_enabled` and the obsolete
nested child `resource_types`/`ignore_body_changes` slots from configuration.
Configure all pool/NAT properties in the root inputs; remove any former LB
collection ignore paths so edits are managed. Keep names, SKU/tier, edge zone,
role GUIDs and lock names unchanged. The stable external replacement object
retains its old shape to avoid a trigger-shape change during this handoff.
Inspect the saved plan for forgotten module bindings and a parent in-place
update, **not child deletes or parent replacement**. Stop on destructive actions.
No module-child imports belong in this plan. Inventory and explicitly clean up
any forgotten draft telemetry deployments under separately approved scope;
forgetting state does not delete Azure artifacts.

Do not use these root-relative removals to retire standalone modules in another
consumer. Their ownership transfer needs its own non-destructive state procedure.
Never keep a standalone module writing collections now owned by this root.

## PIP adoption without replacement

Capture from released state and Azure readback: ARM ID, actual name, RG and
subscription, location, edge zone, zones, SKU/tier, allocation method/version,
DNS label and reverse FQDN, idle timeout, prefix, DDoS mode/plan, IP tags and
resource tags. Capture inherited and non-inherited locks/notes, diagnostic names
and destinations, and assignment GUIDs.

Configure the PIP in the consuming resource composition, preserving those
values. Do not guess its RG from the LB RG; cross-scope PIPs were supported.
Configure its extension resources with their actual existing names and IDs.
At the consumer root, declare explicit imports to the new owner's real address,
for example:

```hcl
import {
  to = azapi_resource.existing_public_ip
  id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/existing/providers/Microsoft.Network/publicIPAddresses/existing?api-version=2025-01-01"
}
```

Use the actual configured address and ID, not this placeholder. PIP extensions
are separate imports. These consumer imports are necessary because the new owner
is outside the LB module, not a reason to run blanket imperative state edits.
In one state, review the combined forget/import plan. Across states, freeze both
pipelines, serialize forget then adoption, and verify after each step.

No PIP or extension may be left permanently unmanaged. If adoption configuration
or GUID/name inventory is missing, stop before applying.

### Import-ID casing qualification

The executed upgrade's first consumer-owned PIP diagnostic import used the
lower-cased parent type spelling returned by Azure, while the unchanged
consumer declared canonical casing. AzAPI proposed replacement solely on
`parent_id`; that saved plan was rejected and never applied.

After asserting case-insensitive ARM identity equality, the captured import ID
was canonicalized to the already-declared PIP parent plus captured diagnostic
name. No product HCL, state or Azure identity was changed to force convergence.
A new separately saved zero-replacement plan was reviewed and applied.
Preserve both rejected and accepted plans. Do not treat arbitrary casing
rewrites or replacement as a safe import recipe.

## Evidence required before applying

1. Apply the released baseline in an explicitly authorized isolated scope.
2. Capture protected state, Azure objects and a clean baseline plan.
3. Switch that **same state** to the exact candidate and perform only the
   configuration changes in the root README.
4. Inspect the saved migration plan JSON. Explain every import/move/forget/update;
   reject unintended delete/replace actions.
5. Apply that saved plan, verify identities and memberships, and require clean
   follow-up and migration-flag-off plans.
6. Test ReadOnly-lock removal, lock/RBAC interaction, telemetry enabled/disabled,
   collection updates/removals, NIC owner handoff and independent PIP adoption.
7. Detach test NICs through their owner; destroy the migrated fixture; verify
   empty states and no retained resources except explicitly authorized ones.

The executed `7ebb946` path satisfies the scoped baseline, migration,
identity/convergence, NIC-owner and cleanup checks above. Deliberate LB
replacement, standalone Frontend-pool destruction, enabled telemetry,
traffic/failover and broad optional/null combinations remain unproved.
Selective operations under locks require separate review. Retargeting explicit
members to another VNet while native NICs stayed in the original was rejected by
Azure; that failed case does not validate a whole-LB VNet migration.
The experimental child-composition draft procedure above was not this released
baseline upgrade and remains separately unverified.

## Rollback limitations

Before any apply, abandoning a reviewed plan is safe. After state/Azure mutation,
a source revert does not reconstruct forgotten/imported addresses or guarantee
restored relationships. Preserve backups and stop for an independently reviewed
recovery plan. No post-apply rollback has been tested. Do not restore old state
and apply it blindly against the migrated Azure objects.
