# Native NIC membership ownership

Native LB membership is writable on the NIC:
`ipConfigurations[].properties.loadBalancerBackendAddressPools`.
The pool's NIC projection is read-only and includes synthesized address/NAT
back-references. Replaying that projection or sending `[]` is not a NIC
membership operation and can fail with
`ModificationOfNICIpConfigBackendPoolNotSupported`.

The LB module owns pool definitions, exports pool IDs keyed by input keys, and
never owns the NIC. NIC is the default pool mode for omission/null. These pools
omit member projections and have no explicit-member action, updater or cleanup.
Pass pool IDs to the resource/module owning each NIC IP configuration using
its supported membership input, such as `backend_address_pool_resource_ids`.
Keep the complete desired list, including pools belonging to other LBs.

Do not attach native NICs to IP/Frontend pools or place explicit IP members in
NIC pools. Use separate pools on the same LB. The LB can validate its explicit
inputs but cannot inspect all attachments made by other states.

## Existing association handoff

1. Back up state and inventory the actual NIC/IP-configuration IDs and complete
   pool membership lists. Freeze all competing pipelines and external writers.
2. Configure those same complete lists in the existing NIC owner. Preserve NIC
   identity, IP configuration names and every unrelated property.
3. Review its plan and independent readback. Do not introduce a second NIC
   updater or infer memberships from matching private IP addresses.
4. Retire the LB-side `backend_address_pool_network_interfaces` input.
   The module's `removed { destroy = false }` declarations forget released
   association bindings without detaching memberships. Native pools require no
   new mode input: omission uses NIC.
5. Review the LB and NIC owner plans separately, serialize applies where states
   differ, then verify unchanged memberships and refreshed convergence in both.

Forgetting an association does not configure its future owner. Do not leave
relationships permanently unmanaged. A provider mutex protects only one local
provider process, not cross-state or external writes.

## Mode changes and recovery

Keep populated IP pools explicitly `"IP"`; clear explicit members under their
current owner before a separately reviewed transition to NIC. Detach native
NICs through their owner before transitioning away from NIC.

If an older pre-release configuration erroneously created an explicit-member
updater/cleanup binding for an already-native pool, merely changing to NIC can
schedule its destroy-time empty PUT and fail. Do not send that request.
Use the narrowly scoped recovery in the [upgrade guide](upgrade-v0.5.0.md);
it is not the ordinary v0.5.0 migration or a generic state-removal recipe.
