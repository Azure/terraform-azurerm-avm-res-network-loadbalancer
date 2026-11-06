# Upgrading from v0.5.0 to AzAPI

Use Terraform >=1.16 and <2.0 and the module's declared provider constraints
(effective root AzAPI >=2.13). Retain the released AzureRM provider configuration
until conversion has removed its state bindings. Do not change state/backend
or workspace during the upgrade.

## Prepare configuration

Back up protected state and capture actual ARM IDs, names, assignment GUIDs,
locks/notes, PIP properties, diagnostic destinations and memberships.
Preserve identity, input keys and resolved child names.

- Replace `resource_group_name` with the existing resource group's `parent_id`.
- Configure all live frontend, pool, probe, rule, NAT and outbound collections.
  Collections are authoritative; omissions can remove existing objects.
- Native pools use the NIC default with no new input and no explicit-member
  writer/cleanup. Explicit IP pools must set `backend_address_type = "IP"` and
  declare every member. Global pools explicitly use `"Frontend"` and actual
  regional frontend IDs. Modes do not convert existing Azure pools.
- Transfer PIP creation and extensions to the consumer composition. Pass
  `public_ip_address_resource_id` rather than bundled creation/inheritance inputs.
- Replace legacy diagnostic category arrays with canonical `logs` and
  `metrics` objects. Preserve actual diagnostic names and destinations.
- Configure the complete native membership lists in the NIC owner before
  retiring `backend_address_pool_network_interfaces`.
- Replace removed whole-resource outputs with `resource_id`, `name` and the
  discrete child-ID maps, which retain input keys. AzureRM object shapes are
  not emulated.

## Module-owned state path

Addresses below are relative to the existing LB module. Prefix with the real
nested/keyed consumer address, for example
`module.workload["app"].module.load_balancer.`. The boundary and collection keys
remain unchanged; no wildcard resource-to-submodule move is required.

| Released address | New owner and migration |
|---|---|
| `azurerm_lb.this` | `azapi_resource.this`, provider move |
| `azurerm_management_lock.this[0]` | `azapi_resource.lock[0]`, provider move |
| `azurerm_monitor_diagnostic_setting.this[key]` | `azapi_resource.diagnostic_settings[key]`, provider move |
| `azurerm_role_assignment.this[key]` | `azapi_resource.role_assignments[key]`, provider move preserving native GUID |
| `azurerm_lb_backend_address_pool.this[key]` | Parent pool metadata; old binding forgotten without destruction |
| `azurerm_lb_backend_address_pool_address.this[key]` | Dedicated explicit-member endpoint lifecycle; synthetic binding forgotten |
| `azurerm_lb_probe.this[key]`, `azurerm_lb_rule.this[key]` | Parent probes/rules; old bindings forgotten |
| `azurerm_lb_nat_rule.this[name]`, `azurerm_lb_nat_pool.this[name]` | Parent NAT collections; old bindings forgotten |
| `azurerm_lb_outbound_rule.this[name]` | Parent outbound collection; old binding forgotten |
| `azurerm_network_interface_backend_address_pool_association.this[key]` | NIC owner; binding forgotten without detaching |
| `azurerm_public_ip.this[key]` and `.pip` lock/diagnostic/RBAC bindings | Consumer PIP/extension owners; old bindings forgotten, captured objects imported by consumer |

Ordinary upgrades need **no root migration flag, captured-ID map or RBAC
imports**. The declarative role-assignment move preserves the actual GUID from
AzureRM state; `ignore_changes = [name]` prevents a generated configured name
from replacing it. Body comparisons and immutable-input replacement controls
remain active. Keep role inputs unchanged during migration.

The parent adopts configured metadata and referencing rules. Explicit-member
updaters/actions require no pool imports and do not own pool creation/deletion.
They write authoritative lists after parent adoption. Native pools receive
neither that writer nor its fixed-empty cleanup. See [member behavior](ip-member-persistence.md).

## Narrow delegated-role exception

AzureRM assignments with `delegated_managed_identity_resource_id` can carry a
composite state ID `ARM-ID|tenant`. AzAPI 2.13's generic role-assignment converter
does not strip that suffix. This is distinct from tenant-level role-definition
ID normalization. Do not apply a malformed move or generate a new GUID.

Only for a captured composite assignment:

1. Freeze writers and back up state. Record the full old address, composite ID,
   exact ARM ID before `|`, tenant suffix, GUID, scope and unchanged role inputs.
   Verify the captured ARM assignment exists and matches that GUID/scope.
2. In the real consumer root, add an explicit import for that one destination:

   ```hcl
   import {
     to = module.workload["app"].module.load_balancer.azapi_resource.role_assignments["delegated"]
     id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/existing/providers/Microsoft.Network/loadBalancers/existing/providers/Microsoft.Authorization/roleAssignments/11111111-1111-1111-1111-111111111111?api-version=2022-04-01"
   }
   ```

   Replace the example with the **captured** ARM ID without its tenant suffix
   and the selected role-assignment API version. Never construct a new GUID.
3. Forget only that old binding, without an Azure delete:

   ```powershell
   terraform state rm 'module.workload["app"].module.load_balancer.azurerm_role_assignment.this["delegated"]'
   ```

4. Save and inspect the import plan. Require the existing GUID/identity, no
   assignment create/delete/replace, and explained body changes. Stop if import
   is missing or any replacement is proposed. Apply only the inspected plan;
   verify readback and refreshed no-ops before retiring the one-time import.

State removal/import is **not** the standard RBAC path. Repeat only for actual
composite keys; ordinary assignments continue through the module-owned move.
Do not leave a forgotten assignment unmanaged or restore old state blindly.

## Consumer-owned public IPs

Capture actual PIP ID, scope, name, location, zones, edge zone, SKU/tier,
allocation/version, DNS/reverse FQDN, timeout, prefix, DDoS settings, IP tags and
tags. Capture extension names, destinations, locks/notes and role GUIDs.
Configure the new owner with those values, then import the captured objects to
its real addresses in the consumer root. PIP extensions are separate imports.

Review the combined forget/import plan within one state. Across states, freeze
both pipelines, serialize forgetting and adoption, and verify each stage.
Do not leave PIPs/extensions unmanaged.

AzAPI imports can propose replacement for case-only differences in `parent_id`.
For diagnostics and other extensions, first prove case-insensitive ARM identity
equality, then use the captured child name with the already-configured canonical
parent spelling. Save and inspect a new plan; reject replacement, do not apply
it as a casing fix.

## Older pre-release ownership recovery

Consumers of older pre-release configurations relying on the former IP default
must explicitly pin every existing IP pool to `"IP"` before upgrading. The new
NIC default is not a request to convert populated IP pools.

An already-native pool may have an erroneous prior explicit-member
`backend_members[pool_key]` updater and `clear_backend_members[pool_key]` cleanup
binding. Switching mode/removing those bindings normally schedules the stored
destroy-time `[]` PUT, which is invalid against native NIC references.

Stop and inspect protected state, Azure membership and the saved plan. Either
detach native NICs through their sole NIC owner under separately reviewed scope,
or, **only when these are erroneous prior bindings with no desired explicit
members**, selectively forget the partial updater/cleanup bindings without
Azure writes. Back up state; verify the exact addresses first:

```powershell
terraform state rm 'module.workload["app"].module.load_balancer.azapi_update_resource.backend_members["native"]' 'module.workload["app"].module.load_balancer.azapi_resource_action.clear_backend_members["native"]'
```

Use actual captured addresses, never wildcard removals. The stateless action
has no state binding. Keep the LB/pool and NIC owner bindings intact, configure
NIC mode and review a new plan for no explicit-member calls or lost membership.
Verify native relationships and convergence before unfreezing writers.
This is not a generic mode-switch procedure or the ordinary v0.5.0 path.

Earlier root child-module calls have separate nondestructive whole-call
removals; see [composition](child-composition.md). Standalone child adoption
flags/imports remain available and are not root upgrade controls.

## Apply and verify

Review every move, import, forget, addition and update in the saved plan.
Reject unintended deletion/replacement, changed GUIDs or lost membership.
Apply only that plan, verify independent Azure identities/relationships and
require two normal refreshed no-op plans. Retire exceptional one-time imports
and verify again. Coordinate locking and competing writers; the full-destroy
lock barrier does not unlock selective updates/replacements.

Before apply, an abandoned plan changes nothing. After state/Azure mutation,
a code revert or old-state restore does not reconstruct ownership or guarantee
relationships. Preserve backups and require a separately reviewed recovery
plan; never apply restored old state blindly against migrated objects.
