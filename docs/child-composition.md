# Load balancer child composition boundaries

## Selected ownership model

The root owns **LB child lifecycle and metadata** in `azapi_resource.this`:
frontends, backend pool skeletons/tunnels, probes,
load-balancing rules, inbound NAT rules, outbound rules and legacy NAT pools.
There is no root child-composition switch, second pool lifecycle resource or
object-only module. Explicit IP/frontend lists are never sent by the parent;
one coupled exact-action/refreshing-updater lifecycle owns each non-NIC pool's list.
Configured empty lists remove explicit members at that endpoint.
Inventory and declare the full desired collections before adopting an existing LB.

This is the user-approved practical design, not a pending design decision.
It is a deliberate departure from the current TFRMNFR1 requirement below.
Local checks cannot establish blanket specification compliance.

## Why one complete parent write

The parent must exist before separately managed pool children can be created.
Parent-owned load/outbound rules require an existing pool or one defined in the
same parent PUT. Removing pools from that first PUT leaves dangling references;
feeding child output IDs into it creates a Terraform dependency cycle.
Bootstrapping pools inline and managing them again as full resources creates
competing lifecycle writers and requires imports for objects just created.
The selected design instead keeps pool metadata and referencing rules in the
same parent write, but never includes writable or read-only member fields.
`azapi_update_resource.backend_members[pool_key]` owns only
`properties.loadBalancerBackendAddresses` at the dedicated pool endpoint.
It refreshes the configured list, does not ignore missing properties, and
replays after parent updates through `replace_triggered_by`.
Its deletion is a no-op, not pool deletion or membership cleanup.
Before each updater create/update, a stateless AzAPI action PUTs the exact
desired list plus the root's configured pool metadata. Unlike the updater,
this action does not merge live named arrays. This prevents removed names and
old positional member properties from being carried into a new request.
The subsequent updater retains refresh/drift detection. This is one coupled
list-owner lifecycle, not a second pool lifecycle resource. NIC pools have
neither this action nor an updater. The action halts on failure and has the
provider's fixed 30-minute timeout, without configurable retry/timeouts.

`azapi_resource_action.clear_backend_members[pool_key]` is a distinct
destroy-only fixed-empty PUT, not a refreshing owner. Dependency reversal
clears before updater removal and inline parent pool removal/rename; it also
precedes parent replacement/destroy and deletion of referenced regional LBs.
The lock-removal barrier covers updater and cleanup. The local Terraform
graph model verifies the abstract ordering, not Azure service success.
Exact-candidate lifecycle and upgraded-state proof remain mandatory.

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
| Pool tunnel interfaces and metadata | Writable pool properties | Nested parent LB body |
| Explicit IP / regional frontend members | Dedicated writable pool endpoint | Coupled exact pre-write action and refreshing partial-field updater; fixed-empty destroy cleanup |
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

Metadata/rule changes are parent body updates, often a full LB PUT; explicit
member edits are dedicated pool endpoint updates. No separate pool lifecycle
resource is created by the root. A
provider-process mutex is not a distributed lock: freeze other states/writers.
The lock removal barrier covers the parent, interfaces and member updater/cleanup
resources, not removed root child module calls. ReadOnly locks can prevent updates; full destruction
ordering does not automatically unlock selective changes.

Mocked tests cover stable request construction, identical/reordered inputs,
mutable edits, collection additions/removals, controls and replacement input
wiring. They do **not** exercise real AzAPI refresh/plan modifiers, Azure
normalization, NIC preservation, service disruption or no-op convergence.
Authorized fresh deployment, repeat refresh plans, mutable update/convergence,
same-state v0.5.0 upgrade and cleanup remain untested. Broad optional/null
combinations remain tracked in the evidence matrix, not assumed covered.
