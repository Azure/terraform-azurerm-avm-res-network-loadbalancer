# Load balancer child composition boundaries

## Selected ownership model

The root owns **every LB child collection** in the single `azapi_resource.this`
body: frontends, backend pools (IP addresses and tunnels included), probes,
load-balancing rules, inbound NAT rules, outbound rules and legacy NAT pools.
There is no root child-composition switch, second writer or object-only module.
Configured empty lists remove members; omission is not a preservation mechanism.
Inventory and declare the full desired collections before adopting an existing LB.

This is the user-approved practical design, not a pending design decision.
It is a deliberate departure from the current TFRMNFR1 requirement below.
Local checks cannot establish blanket specification compliance.

## Why one complete parent write

The parent must exist before separately managed pool children can be created.
Parent-owned load/outbound rules require an existing pool or one defined in the
same parent PUT. Removing pools from that first PUT leaves dangling references;
feeding child output IDs into it creates a Terraform dependency cycle.
Bootstrapping pools inline and managing them again as resources creates competing
writers and requires imports for objects just created. It also fails to provide a
generic path for subsequent new pools. A complete LB body resolves the references
in the same write without an unsafe staged lifecycle.

NAT rules follow the same single-authority boundary even though they have an
independent write API. No mandatory `ignore_body_changes` or lifecycle ignore
remains on root collections. Edits and removals must reach Azure.

## Normative requirement and actual API operations

The current [TFRMNFR1](https://azure.github.io/Azure-Verified-Modules/spec/TFRMNFR1/)
says: “Resource modules **MUST** implement each ARM subresource (a child resource
type as defined in the API spec, for example `Microsoft.Example/widgets/parts`
is a subresource of `Microsoft.Example/widgets`) as a Terraform submodule.”
It also requires parent composition and independent consumption of each module.
There is no explicit GET-only exemption. The selected root design does **not**
satisfy that literal composition requirement; it needs upstream clarification or
an accepted exception before it can be described as fully AVM-compliant. This
does not reopen the user-resolved ownership choice.

HTTP operations were inspected in the Network REST contracts for
[2025-01-01](https://github.com/Azure/azure-rest-api-specs/blob/35a34321b9738f30959b2a9d40a40459c2f8dc48/specification/network/resource-manager/Microsoft.Network/Network/stable/2025-01-01/loadBalancer.json)
and [2026-03-01](https://github.com/Azure/azure-rest-api-specs/blob/35a34321b9738f30959b2a9d40a40459c2f8dc48/specification/network/resource-manager/Microsoft.Network/Network/stable/2026-03-01/loadBalancer.json).
A type in a schema catalog is not evidence of child PUT/DELETE support.

| Member | API boundary | Root owner |
|---|---|---|
| Backend pool, inbound NAT rule | Independent GET/PUT/DELETE available | Complete parent LB body, deliberately not separate resources |
| Frontend, probe, load rule, outbound rule | Child paths expose GET/list, no PUT/DELETE | Parent LB body |
| Pool IP addresses, tunnel interfaces | Writable pool properties | Nested parent LB body |
| NAT pools | Parent inline property | Parent LB body |
| NIC memberships | NIC IP-configuration properties; pool back-references read-only | NIC owner, never this module |

Pool operations are `LoadBalancerBackendAddressPools_CreateOrUpdate`/`Delete`;
NAT operations are `InboundNatRules_CreateOrUpdate`/`Delete`. Other child operations
include `LoadBalancerFrontendIPConfigurations_Get`, `LoadBalancerProbes_Get`,
`LoadBalancerLoadBalancingRules_Get` and `LoadBalancerOutboundRules_Get`.
Health/port-mapping POST actions are diagnostic, not child management operations.

## Independently useful standalone modules

`modules/backend-address-pool` and `modules/inbound-nat-rule` remain real,
single-resource modules for **externally managed LBs** whose owners explicitly
delegate/preserve the relevant collection. They are not called by this root.
Never use them alongside this root for the same LB collection, even for
different keys or initially empty root collections.
`examples/child-resources` uses a direct AzAPI parent with explicit delegation;
`default` and `complete` use authoritative root ownership. No object-only
submodule is introduced as a nominal compliance workaround.

## Plan stability, defaults and remaining proof

[AzAPI v2.13.0](https://github.com/Azure/terraform-provider-azapi/blob/v2.13.0/internal/services/azapi_resource.go)
refreshes configured properties from GET and compares bodies semantically. Named
list items are matched by `name` by default; it does not automatically replace
the LB for every body change. Terraform map iteration is lexically ordered by
key. Reference lists and zones are normalized with `sort(distinct(...))`.
Keep input keys and Azure names stable. Renaming a key can reorder the request;
renaming the Azure child is a real remove/add inside the parent update.

Only writable fields are constructed, excluding NIC back-references,
provisioning state, etags and service-generated child IDs. Explicit defaults
remain deterministic. `ignore_null_property=true` omits optional nulls from
requests and comparison, including Dynamic private IPs; empty collections still
mean removal. Null is not a request to reset a server default. Non-null configured
values remain managed; no broad collection ignore is used to suppress drift.
Public frontend zones are inherited from the consumer-owned public IP.

`replace_triggers_refs = ["sku.name", "sku.tier"]` marks immutable body fields.
The stable external `{sku, sku_tier, edge_zone}` object is retained for earlier
draft state continuity and to detect edge-zone transitions to/from null. There
are no timestamps, random values, frontend maps or child collections in those
triggers. AzAPI itself replaces on name, parent scope and normalized location
changes. Frontend edits do not automatically replace the entire LB. Unsupported
child zone/floating-IP changes can be rejected by Azure and need a separately
reviewed migration; in-place Terraform actions are not zero-disruption proof.

All changes to owned child collections are parent body updates, often a full
LB PUT, not independently managed Terraform child create/delete actions. A
provider-process mutex is not a distributed lock: freeze other states/writers.
The lock removal barrier now covers the parent and its interfaces, not removed
root child module calls. ReadOnly locks can prevent updates; full destruction
ordering does not automatically unlock selective changes.

Mocked tests cover stable request construction, identical/reordered inputs,
mutable edits, collection additions/removals, controls and replacement input
wiring. They do **not** exercise real AzAPI refresh/plan modifiers, Azure
normalization, NIC preservation, service disruption or no-op convergence.
Authorized fresh deployment, repeat refresh plans, mutable update/convergence,
same-state v0.5.0 upgrade and cleanup remain untested. Broad optional/null
combinations remain tracked in the evidence matrix, not assumed covered.
