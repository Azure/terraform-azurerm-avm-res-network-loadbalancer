# NIC membership ownership handoff

The load balancer owns its pools. The application/NIC owner owns
`ipConfigurations[*].properties.loadBalancerBackendAddressPools` on the NIC.
Pool IDs are returned by `backend_address_pool_resource_ids` using the input map
keys, not the pools' Azure names.

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
future NIC-owner PUT will preserve memberships. Actual same-state upgrade and
live membership preservation remain untested.

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
