# Composed public load balancer

AzAPI-only supporting infrastructure with an existing-ID PIP composition.
One LB combines a frontend, backend pool, HTTP probe, load-balancing rule,
v2 inbound NAT rule, outbound rule, tags, metrics, a lock and RBAC.

The executing principal needs permission to assign Reader at the LB. Its
principal type in this example is ServicePrincipal; adapt for interactive users.
Deployment, convergence and destruction require separate Azure authorization.
