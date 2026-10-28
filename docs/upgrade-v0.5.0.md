# v0.5.0 to AzAPI — draft upgrade procedure

**Not production-ready. No real-Azure migration or cleanup has been executed.**
The root's atomic inline composition is an explicit outstanding design deviation
from the requested writable-child submodule composition, not a completed gate.

## Baseline and target

- Released baseline: v0.5.0,
  `e83d34778efeb54a1779b968106067cc4b2bad63`.
- Target: use the exact locally committed candidate SHA from the evidence
  record. No validated immutable candidate exists until all local gates pass.
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
| `azurerm_lb_backend_address_pool.this[key]` | LB body's `backendAddressPools`; old binding forgotten, no ARM delete |
| `azurerm_lb_backend_address_pool_address.this[key]` | owning pool's `loadBalancerBackendAddresses`; synthetic binding forgotten |
| `azurerm_lb_probe.this[key]` | LB body's `probes`; old binding forgotten |
| `azurerm_lb_rule.this[key]` | LB body's `loadBalancingRules`; old binding forgotten |
| `azurerm_lb_nat_rule.this[name]` | LB body's `inboundNatRules`; old binding forgotten |
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
members before conversion. NIC-based membership is not written by this module.
Preservation during a parent PUT still requires state-backed Azure verification.
All LB inline collections are authoritative; external children in those
collections must be reconciled before using this draft.

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

## Rollback limitations

Before any apply, abandoning a reviewed plan is safe. After state/Azure mutation,
a source revert does not reconstruct forgotten/imported addresses or guarantee
restored relationships. Preserve backups and stop for an independently reviewed
recovery plan. No post-apply rollback has been tested. Do not restore old state
and apply it blindly against the migrated Azure objects.
