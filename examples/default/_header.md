# Private load balancer and NIC-owner membership

Creates an isolated resource group, private load balancer and NIC using AzAPI.
The NIC owns its IP configuration's backend pool memberships. The LB only
exports pool IDs. This is a fresh-deployment example, not migration proof.

The root enables backend-pool child modules because this example has no
parent-owned load/outbound rule references. The NIC depends on the composed
pool ID output, so its membership is assigned only after pool creation.
