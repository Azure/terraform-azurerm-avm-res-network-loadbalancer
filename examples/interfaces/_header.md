# Composed public load balancer

AzAPI-only supporting infrastructure with an existing-ID PIP composition.
One LB combines a frontend, backend pool, HTTP probe, load-balancing rule,
v2 inbound NAT rule, outbound rule, tags, metrics, a lock and RBAC.

This is interface demonstration coverage, **not production egress guidance**.
For production workloads, prefer NAT Gateway rather than LB outbound rules to
avoid manual SNAT port allocation and exhaustion. This example has one
example-local APRL exception solely to exercise the offered outbound-rule
interface; it does not exempt other resiliency or security rules.

The executing principal needs permission to assign Reader at the LB. Its
principal type in this example is ServicePrincipal; adapt for interactive users.
Deployment, convergence and destruction require separate Azure authorization.
