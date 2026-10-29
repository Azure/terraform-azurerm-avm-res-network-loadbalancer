# Private load balancer and NIC-owner membership

Creates an isolated resource group, private load balancer and NIC using AzAPI.
The NIC owns its IP configuration's backend pool memberships. The LB only
exports pool IDs. This is a fresh-deployment example, not migration proof.

The root manages the complete pool collection in the LB body. The NIC depends
on the parent-dependent pool ID output, so membership is assigned only after
the LB and its configured pool exist. There is no separate pool writer.
