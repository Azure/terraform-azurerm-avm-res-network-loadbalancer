# IP-member persistence: unresolved parent-write boundary

## Status

**Blocked, not fixed.** This draft uses one parent LB writer. Do not adopt its
IP-member management until Azure readback and repeated refreshed plans prove
add, update, remove and last-member clearing. No second pool writer or field
ignore has been added to mask the failure.

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

1. [`locals.tf`](../locals.tf) folds the input map into
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

If the actual parent PUT contains the correct member list but GET omits it,
the approved single-parent management design has no demonstrated IP CRUD
path. Escalate that exact request/response to the service owner, or obtain an
explicit decision to redesign pool ownership. A dedicated pool owner would
require resolving parent-write overlap, creation ordering/cycles, migration
imports, pool removal, lock ordering and destruction before implementation.
Adding a satellite update resource while both it and the parent own the same
list is not a safe solution.

The new unit cases prove only payload construction for these mutations.
They deliberately retain the historical expected-versus-observed mismatch;
they do not simulate ARM persistence or convert the failed live case to PASS.
