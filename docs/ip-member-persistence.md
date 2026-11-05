# IP-member persistence: verified dedicated-endpoint correction

## Status

**Core member-removal and lifecycle correction verified on exact candidate
`7ebb9465497dbae051d4d8ca45aeca718e86c01b`.**
The root now sends pool skeletons/metadata without any member list. A single
refreshing `azapi_update_resource.backend_members[pool_key]` is coupled to a
stateless exact-PUT action at `before_create` and `before_update`. The action
sends the authoritative IP/frontend list through the dedicated endpoint, including
`[]` for last-member removal. A destroy-only fixed-empty action clears explicit
lists before pool removal. None of these partial bindings owns pool lifecycle or NICs.
No blanket ignore has been added to mask the historical failure. The action
does not merge old member arrays. The updater subsequently reads/writes the
corrected pool and retains configured-list drift detection.

Independent Azure verification on 2026-11-04 passed:

- The byte-verified multi-region example: 18 creates, 21 independent
  membership/NIC assertions, two refreshed no-op plans and ordinary automatic
  destruction. The managed Terraform standard E2E sequence was used, not a
  claimed literal `avm test e2e` command pass.
- Sixteen core mutation cases: IP/frontend add, subset removal, last-member
  clear/restore, same-count rename/retarget, parent tag/rule changes, actual
  NIC-owner PUTs, pool removal with its rule, recreation/rename and detection
  and reconciliation of an extra live member. Every passed case reached two
  immediate normal refreshed no-op plans.
- Serialized exact action PUT before updater GET/PUT, with no preliminary
  clear of retained members. Parent responses preserved existing members
  before the subsequent member writes.
- An actual v0.5.0 same-state upgrade with preserved normalized ARM identities
  and interfaces, migration-flag removal, NIC-owner handoff and cleanup.
  The first case-only PIP diagnostic import replacement plan was rejected
  before apply. After case-insensitive identity equality was asserted, the
  import input was canonicalized to the already-declared parent and captured
  name; a separately inspected zero-replacement plan was applied.

Forty normal refreshed no-op plans passed across the complete run. All three
test resource groups were absent and all four states empty after cleanup;
no recoverable test workspace remained. Telemetry was disabled and no VMs
or traffic were deployed. This is not a VM-AVM coexistence result.

The additional attempt to retarget IP members to another VNet while native
NICs stayed in the original VNet failed with
`LoadBalancerBackendAddressesMustBelongToSameVNET`; it remains a failed,
unsupported combination, not a valid whole-LB VNet migration pass.
Deliberate LB replacement, standalone Frontend-pool destruction, enabled
telemetry and traffic/failover remain unproved. Documentation-only descendants
may retain these results only with unchanged runtime/dependency/migration
sources; the tested runtime SHA remains `7ebb946`.

## Exact-candidate removal failure and correction

On `ab278cc42f3023e2ea65814db1ab8845a771bd89`, the byte-verified multi-region
example passed 18 creates, 21 independent membership checks, two refreshed
no-op plans and ordinary 18-resource destroy with automatic fixed-empty clears.
Parent tags, Global floating-IP and real NIC-owner updates also passed, with
members present in parent responses before updater replay.

Removing west from the Global pool **failed**: plan and configured state were
east-only, apply returned success, but captured outgoing pool PUT contained
east and west. Both Azure GETs returned both and a fresh plan repeated the
update. Both fixtures cleaned up normally through that unchanged SHA.
Migration was stopped before baseline deployment. These old-SHA passes and the
failed removal remain distinct, not a pass for this correction.

Pinned [AzAPI 2.13 merge code](https://github.com/Azure/terraform-provider-azapi/blob/v2.13.0/utils/json.go)
appends unmatched old entries in named arrays. `ignore_missing_property=false`
and `ignore_other_items_in_list` affect read shaping, not this write merge.
Using `list_unique_id_property = "id"` is not a robust replacement: same-length
positional merges can copy an old synthesized frontend IP or omitted VNet.
No fake identity key or such fallback is used.

The supported [stateless action](https://github.com/Azure/terraform-provider-azapi/blob/v2.13.0/internal/services/azapi_resource_action.go)
serializes the configured body without reading/merging the target. Its exact
PUT runs before each updater create/update, including drift-driven changes.
The root's configured pool metadata accompanies the list so it is not silently
dropped. There is no preliminary clear-all write, new pool lifecycle owner,
state address change, ignored member drift or native NIC snapshot.
The existing fixed-empty destroy cleanup remains separate and unchanged.

Tradeoffs: two PUTs per changed explicit pool; stateless actions have a fixed
30-minute provider timeout and no configurable retry/timeouts in AzAPI 2.13.
Failure halts apply. These operations are not atomic; after a partial failure,
inspect a refreshed plan before retrying. Terraform >=1.16 and the root's
effective AzAPI >=2.13 dependencies already exist.

An offline regression compiles against the exact upstream provider source
(`cf3ecee858fa48c0aca95d0b995a8bfd4950c8ec`), invokes its real action and updater
methods, and captures the real ARM HTTP serialization through a fail-closed
in-memory transport. It exercises IP/Frontend 2→1→0→restore, same-count
rename/retarget/reorder, omitted/null VNet, server-added fields, repeated Read
shaping and external member drift. Run it separately from mocked Terraform tests:

```powershell
./tests/provider/Test-BackendMemberWrite.ps1 -Workspace <new-protected-external-directory>
```

Git and compatible Go are test-only prerequisites; only the pinned provider's
existing dependency graph is used with `-mod=readonly`. No provider binary
override, Azure authentication or real HTTP transport is used. This is provider
request/refresh proof, not Azure persistence or Terraform's real apply graph.
The managed unit and PR gates remain mandatory.

## Earlier parent-endpoint investigation

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

## Ownership decision and remaining proof

For future runtime, dependency or migration changes, reproduce in a new isolated
RG with the exact candidate and pinned providers.
Capture the actual parent request, response and two independent GETs, including
the dedicated pool GET. Assert exact names, IPs, VNet IDs and cardinality, then
require two fully refreshed no-op plans after each mutation. Stop at the first
failure and preserve it. Verify unchanged NIC memberships/backlinks and IDs.

The now-approved correction deliberately removes the entire member field from
the parent instead of adding a competing list writer. Pool metadata/rules
bootstrap together, then the exact pre-write action and refreshing updater
manage members in their coupled lifecycle. Partial
bindings require no second pool import. Parent edits replay that owner, while
fixed-empty cleanup precedes removal. The lock barrier covers both bindings.
Automatic pool removal/rename, exercised parent/rule mutations, native-member
preservation, frontend teardown and v0.5.0 adoption passed on `7ebb946`.
The upgrade included locks with grants/diagnostics and their ordered cleanup;
it did not establish arbitrary selective operations under locks. Deliberate
LB replacement and standalone Frontend-pool destruction remain separate gates.
Stop on lost membership, repeated drift or failed cleanup; a mock pass cannot
satisfy these gates.

The Terraform unit cases prove payload construction and mocked lifecycle
configuration only. The separate pinned-provider regression proves serialization
and provider refresh shaping against an in-memory sink. Neither proves Azure
persistence or real Terraform apply ordering. Historical expected-versus-observed
mismatches remain failures, never converted to PASS by these local tests.
