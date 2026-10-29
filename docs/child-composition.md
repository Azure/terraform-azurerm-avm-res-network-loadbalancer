# Load balancer child composition boundaries

## Normative requirement and actual API operations

The current [TFRMNFR1](https://azure.github.io/Azure-Verified-Modules/spec/TFRMNFR1/)
says: “Resource modules **MUST** implement each ARM subresource (a child resource
type as defined in the API spec, for example `Microsoft.Example/widgets/parts`
is a subresource of `Microsoft.Example/widgets`) as a Terraform submodule.”
It also says: “The parent module **MUST** reference and compose its submodules
so that supported subresources can be expressed through the parent module, but
each submodule **MUST** also be independently consumable.”

It does **not** explicitly exempt GET-only child resource types, nor limit its
first sentence to independently writable resources. Treating inline objects as
outside the rule is therefore not established compliance. This draft retains
inline ownership only where the actual API prevents a safe independent lifecycle;
it needs an upstream specification clarification or supported API/provider path
before full completion can be claimed.

HTTP operations were inspected in the Network REST contracts for both the
[selected 2025-01-01 API](https://github.com/Azure/azure-rest-api-specs/blob/35a34321b9738f30959b2a9d40a40459c2f8dc48/specification/network/resource-manager/Microsoft.Network/Network/stable/2025-01-01/loadBalancer.json)
and [latest published stable 2026-03-01 API](https://github.com/Azure/azure-rest-api-specs/blob/35a34321b9738f30959b2a9d40a40459c2f8dc48/specification/network/resource-manager/Microsoft.Network/Network/stable/2026-03-01/loadBalancer.json).
A type in a schema catalog is not evidence of PUT/DELETE support.

| Member | Actual operations | Implemented owner |
|---|---|---|
| Backend pool | GET, PUT, DELETE | Child module when child-pool mode is enabled; otherwise inline for coupled parent rule references |
| Inbound NAT rule | GET, PUT, DELETE | Root-composed, single-instance child module per input key |
| Frontend, probe, load rule, outbound rule | Resource paths expose GET/list, no PUT/DELETE | Authoritative parent body; no invented child lifecycle |
| Pool IP addresses, tunnel interfaces | Writable pool properties, not separate lifecycle endpoints | Owning pool body |
| NAT pools | Parent inline property; no independent lifecycle endpoint | Authoritative parent body |
| NIC memberships | NIC IP-configuration properties; pool back-references are read-only | NIC owner, not this module |

The writable operation IDs are `LoadBalancerBackendAddressPools_CreateOrUpdate`,
`LoadBalancerBackendAddressPools_Delete`, `InboundNatRules_CreateOrUpdate` and
`InboundNatRules_Delete`. The other child resource operations are
`LoadBalancerFrontendIPConfigurations_Get`, `LoadBalancerProbes_Get`,
`LoadBalancerLoadBalancingRules_Get` and `LoadBalancerOutboundRules_Get`.
Both API versions also expose diagnostic POST actions:
`LoadBalancerLoadBalancingRules_Health` (“Get health details of a load balancing
rule”) and `LoadBalancers_ListInboundNatRulePortMappings`. Neither action
creates, updates or deletes the child resource.

## Why pools used by inline rules are different

The parent must exist before child pools can be created. Parent-owned load and
outbound rules reference existing pools or pools defined in that same parent
PUT. Removing the pool definitions from the first PUT leaves dangling references;
feeding child output IDs into that PUT creates a Terraform dependency cycle.
Bootstrapping inline pools and then creating `azapi_resource` children also fails:
AzAPI checks existence on create and requires an import for an existing object.
Blind imports cannot also create missing pools during subsequent additions.

This implementation provides explicit child-pool mode for the acyclic subset,
including pool references from composed NAT rules. It rejects parent-owned rule
references to those configured pools by input key or case-insensitive ARM ID.
No automatic ownership switching, bootstrap/adopt trick, second parent resource,
generic updater deletion, destroy-time snapshot replay or external script is used.
The default coupled-inline path remains an explicitly unresolved case.
Pool ownership is collection-wide: mixing inline-owned and child-owned pools
is not supported. AzAPI's preservation paths cannot merge selected named
members of the pool array while updating other members authoritatively.

## Preservation, concurrency and remaining proof

The parent creates real frontends in its initial PUT. It sends `inboundNatRules`
as an empty placeholder; child-pool mode also sends an empty pool placeholder.
On updates, its mandatory preservation paths are added to consumer-selected
`ignore_body_changes`. In [AzAPI v2.13.0 `CreateUpdate`](https://github.com/Azure/terraform-provider-azapi/blob/v2.13.0/internal/services/azapi_resource.go),
non-new resources are GET before PUT; ignored paths are replaced with live
values and the result is filtered through `GetWriteOnly`. New resources do not
perform this merge. Omission alone is not safe preservation.

Parent and children use one parent-ID mutex. Parent dependencies order updates
before child operations; child NAT depends on pools. The management lock depends
on the removal-delay barrier, which depends on all children and interfaces.
The mutex serializes writes within one provider process, not across states, and
AzAPI performs its preservation GET **before** acquiring it. Freeze external
writers during adoption/updates. NIC memberships are never written deliberately;
live preservation of server-maintained references still requires Azure readback.

Each composed child owns its import block and tested API default; the root
cascades `avm_managed_migration_enabled`. Imports target the same keyed child
addresses documented in the upgrade guide, including in nested consumers.
Remove referencing NAT rules in a separate apply before removing their pool or
frontend. Remove an applicable management lock before selective child removal
or replacement; the full-destroy lock barrier does not unlock selective changes.
Choose pool ownership before creation or use the gated adoption path. Switching
child-pool mode back to inline is not a supported non-destructive handoff.

Mocked tests prove configuration, graph wiring and policy-compatible examples,
not service behavior. Pending authorized proof: fresh apply, parent tag/frontend
updates preserving child identities and properties, NIC relationship handoff,
child additions/removals, convergence, baseline-to-candidate import/forget,
migration flag removal, and cleanup. No real-Azure test has been performed.
