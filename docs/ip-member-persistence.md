# IP-member persistence: dedicated-endpoint correction awaiting candidate proof

## Status

**Implementation corrected; exact-candidate runtime proof still pending.**
The root now sends pool skeletons/metadata without any member list. A single
refreshing `azapi_update_resource.backend_members[pool_key]` writes the
authoritative IP/frontend list through the dedicated endpoint, including
`[]` for last-member removal. A destroy-only fixed-empty action clears explicit
lists before pool removal. Neither resource owns pool lifecycle or NICs.
No blanket ignore has been added to mask the historical failure.

Diagnostic dedicated-endpoint experiments persisted explicit IP and real regional
frontend members. A separate skeleton diagnostic preserved IP+VNet and actual
frontend references across parent tag writes, and IP members across regional
probe/rule writes without scheduling a restorative updater. Its Global
probe/rule stage failed because the fixture incorrectly configured a Global
health probe (`GlobalLoadBalancerCanOnlyContainLoadBalancingRules`). That failure
is preserved, not reclassified. The implementation rejects Global health
probes, rule probe references, NAT and outbound configuration.
The corrected independent Global rule-only follow-up subsequently passed
TCP80-to-80 addition and a floating-IP edit, twice-refreshed no-op plans after
each, and actual serialized skeleton request bodies with member fields omitted.
It retained both actual frontend references with no restorative member writes.
Separate failed TCP-reset and port-translation requests remain failures; the
module now validates both restrictions and emits singular backendAddressPool
for one Global rule pool. These diagnostics are not this candidate's E2E or
migration evidence. The first run's planned body/source/readbacks remain distinct
from the corrected follow-up's actual serialized wire evidence.

The independent test of `dce02d370272893ab408a7f8828eba9e752d3899` on
2026-11-04 applied a saved plan adding `second=10.40.1.11` alongside
`static=10.40.1.10`. Apply returned success. Two subsequent ARM GETs returned
only `static`; a refreshed plan again proposed the addition. Update, removal
and clearing were stopped, not passed. The isolated test was cleaned up.

## What the actual artifacts establish

- The fixture used a separate pool named `ip`, explicitly in module IP mode.
  The NIC memberships targeted different pools, `app` and `retained`.
- Both planned members used `properties.ipAddress` and
  `properties.virtualNetwork.id`, with the same actual VNet as the original.
- The only changed resource field was the parent LB `body`. No replacement,
  membership handoff, pool mode switch or blanket ignore was involved.
- `backend_address_type` is a module ownership choice, **not** an ARM property.
  The actual IP-pool GET has neither `backendIPConfigurations` nor
  `networkInterfaceIPConfiguration` nor `syncMode`/`backendAddressType`.
  Absence of `syncMode` does not prove a specific service default.
- Pool-level `virtualNetwork` and `location` were absent in the original GET
  and omitted in the request; VNet references were present on both members.
- The captured parent and pool etags were unchanged across the IP addition.
  This alone does not distinguish an ignored PUT from a skipped request.
- No HTTP wire trace was retained for that apply. A saved Terraform plan is
  not a captured request. The precise service-versus-provider boundary still
  needs an instrumented reproduction.

## Source trace and authority

1. The failed historical implementation folded the input map into
   `properties.backendAddressPools[].properties.loadBalancerBackendAddresses`.
   IP mode retains an explicit empty array; NIC mode omits only the
   server-maintained address projection.
2. [AzAPI 2.13.0 `azapi_resource.go`](https://github.com/Azure/terraform-provider-azapi/blob/v2.13.0/internal/services/azapi_resource.go#L811-L984)
   compares `Body` before skipping an update. Body is not tagged as state-only.
   The request is built from the planned body. Writable-schema filtering runs
   in the nonempty `ignore_body_changes` branch, which this test did not use.
   Null removal does not intentionally remove a concrete member list.
   This is source analysis, not a wire trace of the failed run.
3. The [exact 2025-01-01 REST schema](https://github.com/Azure/azure-rest-api-specs/blob/main/specification/network/resource-manager/Microsoft.Network/Network/stable/2025-01-01/loadBalancer.json)
   exposes writable member arrays in the shared pool definition; NIC
   references and NAT port mappings are read-only. Schema acceptance does not
   demonstrate that the parent endpoint persists nested changes.
4. [AzureRM 4.81.0 IP-member implementation](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/internal/services/loadbalancer/lb_backend_address_pool_address_resource.go#L181-L228)
   reads the pool and calls
   `LoadBalancerBackendAddressPoolsCreateOrUpdateThenPoll`; deletion also
   updates the dedicated pool endpoint. It does not rely on a parent LB PUT
   to update IP members.
5. [Microsoft backend-pool guidance](https://learn.microsoft.com/azure/load-balancer/backend-pool-management)
   uses the backend-pool operation and permits NIC and IP pools on one LB,
   but not mixed NIC/IP members within a single pool.
6. [Azure/bicep-types-az#1861](https://github.com/Azure/bicep-types-az/issues/1861)
   reports the same silent parent deployment failure.
   Its [reported workaround](https://github.com/Azure/bicep-types-az/issues/1861#issuecomment-1802158590)
   is a separate `loadBalancers/backendAddressPools` deployment, not another
   parent PUT. This is corroborating issue evidence, not proof for every API
   version. The [dedicated REST operation](https://learn.microsoft.com/rest/api/load-balancer/load-balancer-backend-address-pools/create-or-update)
   documents member-list writes; the Learn page currently redirects to
   2026-01-01, which is **not** a proposed dependency or API upgrade here.

**Leading diagnosis:** moving IP-member writes from the dedicated pool
endpoint to the parent endpoint lost persistence. The fixture is not shown
to be invalid. A casing change, guessed `syncMode`, broad ignore, or API
upgrade is not an evidence-backed fix.

## Required independent proof and design decision

Reproduce in a new isolated RG with the exact candidate and pinned providers.
Capture the actual parent request, response and two independent GETs, including
the dedicated pool GET. Assert exact names, IPs, VNet IDs and cardinality, then
require two fully refreshed no-op plans after each mutation. Stop at the first
failure and preserve it. Verify unchanged NIC memberships/backlinks and IDs.

The now-approved correction deliberately removes the entire member field from
the parent instead of adding a competing list writer. Pool metadata/rules
bootstrap together, then the refreshing endpoint owner writes members. Partial
bindings require no second pool import. Parent edits replay that owner, while
fixed-empty cleanup precedes removal. The lock barrier covers both bindings.
Actual automatic pool removal/rename, metadata/rule mutation, LB replacement,
lock interaction, frontend teardown and v0.5.0 adoption must still be exercised
on the frozen candidate. Stop on lost membership, repeated drift or failed
cleanup; a mock pass cannot satisfy these gates.

The new unit cases prove only payload construction for these mutations.
They deliberately retain the historical expected-versus-observed mismatch;
they do not simulate ARM persistence or convert the failed live case to PASS.
