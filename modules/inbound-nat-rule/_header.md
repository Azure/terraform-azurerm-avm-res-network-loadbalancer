# Inbound NAT rule

**Draft standalone module.** The root LB does not compose this module. Do not
use it against an LB whose root configuration owns the same inline NAT rules.
That would introduce conflicting ownership.

Manages one v1 scalar-port or v2 backend-pool port-range NAT rule.
The calling module owns cardinality and reference ordering.
