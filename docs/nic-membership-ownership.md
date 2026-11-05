# NIC membership ownership handoff

The load balancer owns pool definitions and explicit IP/Frontend member lists.
The application/NIC owner exclusively owns native associations in
`ipConfigurations[*].properties.loadBalancerBackendAddressPools` on the NIC.
Pool IDs are returned by `backend_address_pool_resource_ids` using the input map
keys, not the pools' Azure names. Supply these IDs to the NIC/compute owner's
supported membership configuration; do not introduce a second NIC writer.

## Why LB-side native association management was retired

The released association input let the LB configuration write a property on an
application-owned NIC. The AzAPI migration retires that input and deliberately
does not replace it with an LB-side NIC updater. A pool's NIC back-references
are not an independently writable association lifecycle. An external NIC write
also needs an explicit preservation/delegation contract with the NIC owner,
plus safe selective detach that retains unrelated configurations/memberships.
Successful attachment alone establishes neither contract.

An isolated actual-VM diagnostic on 2026-11-05 demonstrated the conflict:
compute's next NIC PUT removed a membership attached outside its declared
configuration. Allowing the external updater to restore it in the same apply
would have hidden the loss, not established stable ownership. This result
supports keeping native membership with the NIC owner; it does not assert that
every compute version/provider behaves identically.

### Frozen diagnostic and observed result

| Component | Exact tested configuration |
|---|---|
| LB runtime | `7ebb9465497dbae051d4d8ca45aeca718e86c01b` |
| Compute AVM | Unreleased AzAPI `main`, pinned `9cd85039358a12f744752a7e8ce519d0e692a1eb` |
| Terraform / AzAPI | 1.16.5 / 2.13.0 |
| Compute / diagnostic NIC API | `2024-10-01` / `2025-01-01` |
| Actual VM | Nonzonal `Standard_B2s_v2`, West US 2, `Canonical:ubuntu-24_04-lts:server:24.04.202610210`, private-only NIC, deny-inbound NSG |
| NIC controls | Two static IP configurations; an unrelated native association on the secondary configuration |

Baseline creation and two full refreshed no-op plans passed. A separate
diagnostic fresh-read/merge updater attached the primary configuration to the
test pool. NIC GETs and pool reverse-reference GETs confirmed attachment and
retention of the secondary association. This was an external diagnostic fixture,
not an implementation of native membership in this LB module.

The two immediate post-attachment plans did **not** converge: the diagnostic
updater's refresh expanded its `ipConfigurations` state to include the unmanaged
secondary configuration. That separate list-scope flaw is retained as a failure,
not attributed to compute stripping membership.

A reviewed, isolated compute-owned NIC PUT then changed only
`ip_forwarding_enabled` from false to true. Independent Azure reads showed the
primary native association and its pool backlink had disappeared. The unrelated
secondary association, VM/NIC GUIDs, both IP configurations, subnet, NSG, DNS and
tags remained unchanged. Both subsequent full refreshed plans wanted the
diagnostic updater to restore the missing association. No restoration apply,
broad ignore or repeated alternation was used; testing stopped on first loss.

### Reproduction and evidence boundaries

1. In a separately authorized isolated scope, freeze the exact pins above and
   deploy an actual compute-AVM VM/NIC plus the LB. Give the NIC two static IP
   configurations: omit `load_balancer_backend_pools` from
   `network_interfaces.primary.ip_configurations.primary`, and declare the
   secondary sentinel through
   `network_interfaces.primary.ip_configurations.secondary.load_balancer_backend_pools.sentinel.load_balancer_backend_pool_resource_id`.
   Require two full refreshed baseline no-op plans before attachment.
2. Use an external diagnostic updater to attach the primary native membership.
   In the executed fixture, `azapi_update_resource.diagnostic_attachment[0]`
   targeted `module.compute.network_interfaces["primary"].id` and requested
   the primary IP configuration's native pool reference using
   `module.loadbalancer.backend_address_pool_resource_ids["diagnostic"]`,
   with `ignore_missing_property=false` and no ignores.
   Read the NIC and both dedicated pools independently; preserve the two
   post-attachment plans, including any diagnostic list-scope drift.
3. Change only `network_interfaces.primary.ip_forwarding_enabled` to true.
   Save a plan with
   `terraform plan -input=false -no-color -target=module.compute -out=compute-write.tfplan`.
   Inspect its JSON: the executed plan contained only an update at
   `module.compute.azapi_resource.virtualmachine_network_interfaces["primary"]`,
   with no VM change, replacement or diagnostic repair. Apply the saved plan
   without the diagnostic updater, so reattachment cannot conceal compute's
   behavior. Retain the targeting warning; targeting is diagnostic isolation,
   not a recommended normal deployment workflow.
4. Before another apply, read the NIC and both pools again and take two normal
   full refreshed plans. Compare memberships, backlinks and unrelated NIC/VM
   properties. Stop on loss; destroy through the compute owner, then the LB and
   supporting resources, and verify empty state and resource-group absence.

Protected diagnostic artifacts retain `nic-coexistence-research.json` and
`nic-diagnostic-attempt2/verified-result.json`, the fixture/source fingerprints,
sanitized planned NIC payload, actual PUT URLs and before/after Azure GETs.
The result records `requirementResult="FAIL"` and twelve successful evidence
assertions establishing that negative result, not twelve passing coexistence
tests. Key supporting files in `nic-diagnostic-attempt2` include
`compute-write-sanitized-plan.json`, `compute-write-put-requests.txt`,
`attached-snapshot.json`, `after-compute-write-snapshot.json` and
`cleanup-verified.json`. These are protected session artifacts, not public
evidence links or newly committed Azure identifiers.
Serialized HTTP request bodies were **not** captured (`IncludeBody=false`).
The result is based on actual isolated NIC execution and readbacks, not a claim
that a planned body is a captured wire request. Secret-bearing plans, full debug
logs and state backups were removed after redacted evidence was validated.

Normal destroy removed the actual VM/OS disk, then NIC before LB, and remaining
supporting resources. State was empty and both attempt resource groups absent.
The earlier `Standard_B2s` capacity failure remains a separate failed attempt,
not a coexistence result. The successful baseline retry did not change that
history or turn the negative ownership test into a pass.

## Choose a separate pool for native NIC membership

Set `backend_address_type = "NIC"` for the pool passed to the NIC owner.
Configure explicit `backend_address_pool_addresses` only against separate
`backend_address_type = "IP"` pools. Both pool types can belong to the same LB,
but Azure rejects a native NIC association on a pool containing explicit IP
members with
`CannotMixIPBasedAddressesAndIPConfigurationsOnLoadBalancerBackendAddressPool`.
Our isolated same-pool VM/NIC test confirmed that rejection.

The LB module can validate an IP input targeting a declared NIC-mode pool. It
cannot inspect or prevent a different module from attempting to attach a NIC to
an IP-mode pool. The NIC owner must consume the correct pool ID. Mode selection
is a module ownership contract, not an automatic conversion of Azure membership.
Do not use IP lookups as a transparent substitute for native NIC membership.

## Existing association bindings

Do **not** empty the association map while still running v0.5.0: that invokes
the AzureRM association destroy operation and detaches memberships.

The AzAPI migration retires the association input entirely and includes:

```hcl
removed {
  from = azurerm_network_interface_backend_address_pool_association.this
  lifecycle {
    destroy = false
  }
}
```

This removes all legacy module-owned association bindings without asking Azure
to detach anything. It does not import a NIC, update a NIC, or establish that a
future NIC-owner PUT will preserve memberships by itself.

Independent Azure verification of exact candidate
`7ebb9465497dbae051d4d8ca45aeca718e86c01b` applied v0.5.0 and upgraded the same
nested consumer state. Both native memberships/backlinks and NIC/LB identities
were preserved. A real NIC-owner update sent the complete desired two-pool
membership list; full ARM comparisons and two refreshed no-op plans passed.
Fresh multi-region NIC-owner updates also preserved native memberships.
These fixtures used real NICs without attached VMs and did not prove compute
AVM coexistence or LB-owned native association management.

The upgrade's first consumer PIP diagnostic import plan proposed a case-only
replacement and was rejected before apply; case-equivalent import input
canonicalization produced the separately inspected successful plan.
Migration-flag removal and ordered cleanup also passed. The result is scoped
to the executed same-state handoff, not arbitrary cross-state writer behavior.
Keep the tested SHA attached to this evidence on documentation-only descendants
with unchanged runtime/dependency/migration sources.

1. Freeze applies in both the LB and NIC-owning states.
2. Back up both states outside source control and capture NIC IDs, IP
   configuration names, pool IDs and **all** existing memberships.
3. Prepare the NIC owner's supported configuration so that its complete desired
   membership list includes the LB's existing pool IDs and all memberships it
   must retain. Do not create a second NIC writer. If the NIC owner uses an
   association resource, use that owner's supported adoption procedure rather
   than inventing a direct resource-to-NIC move.
4. Review the LB migration plan: each old association must be **forgotten**,
   never destroyed. Review the NIC owner plan independently: no NIC replacement,
   IP-configuration loss or unintended pool detach is acceptable.
5. Apply the inspected LB migration plan, then the inspected NIC-owner plan
   during the same controlled handoff. Verify live relationships after each.
6. Unfreeze only after both follow-up plans converge.

Cross-state handoff is not an atomic Terraform transaction. Serialize execution,
keep backups and stop on discrepancies. A state import alone does not configure
the owning NIC's desired membership properties. Cross-state dependencies must
not form an apply cycle; use existing, captured IDs for the handoff.

For new deployments see `examples/default`: the one NIC resource writes its own
IP configuration and consumes the pool ID. Pool/LB destruction requires the NIC
owner to detach or destroy its own NIC first. The LB module never does that for
the application.
