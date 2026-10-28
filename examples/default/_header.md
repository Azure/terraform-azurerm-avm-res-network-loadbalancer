# Private load balancer and NIC-owner membership

Creates an isolated resource group, private load balancer and NIC using AzAPI.
The NIC owns its IP configuration's backend pool memberships. The LB only
exports pool IDs. This is a fresh-deployment example, not migration proof.
