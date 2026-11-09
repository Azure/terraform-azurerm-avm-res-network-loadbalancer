# Examples

- [default](default): private LB, AzAPI VNet and a NIC whose owner configures its
  backend pool membership using the module's keyed pool-ID output.
- [interfaces](interfaces): consumer-owned public IP plus pools, probe, load rule,
  NAT rule, outbound rule, diagnostics, RBAC, lock and tags.

These are breaking AzAPI draft examples, not evidence of successful Azure
deployment. Review the root upgrade guide before use. Regenerate documentation
and run local validation with managed Avm.Authoring (`avm pre-commit` and
`avm pr-check`). Real deployment requires separately authorized Azure scope.
