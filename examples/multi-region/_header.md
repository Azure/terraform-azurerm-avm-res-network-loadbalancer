# Multi-region public load balancing

Two Standard Regional load balancers in East US 2 and West US 2 feed a
Standard Global load balancer and Global public IP in the supported East US 2
home region. The Global backend members are real regional public frontend IDs,
not IP snapshots. Global TCP80 forwards to the regional TCP80 rules. Only the
regional LBs configure health probes; the Global LB inherits regional health.
The module clears its explicit frontend-reference list automatically before
pool deletion, including normal Terraform destruction.

Each regional LB has separate explicit-IP and native-NIC pools. Direct AzAPI
support resources supply Standard public IPs, VNets and private NICs. The NIC
owner configures native membership; the LB module never patches NIC bodies.
Names include a random suffix. Destroy using the same Terraform configuration
and state so the cleanup dependency graph is retained.

This economical example deploys no VMs, applications or listening services.
The explicit `.10` addresses are illustrative, unallocated backend addresses;
the `.11` NICs are unattached. It demonstrates control-plane composition, not
healthy backend probes, traffic delivery, failover, availability or SLA proof.
Provision real services separately before expecting traffic.

Run only in an authorized subscription with appropriate permissions and cost
approval. Local mocked tests are not Azure E2E proof; this candidate's
deployment, repeated no-op plans, mutations and automatic cleanup require an
independent exact-commit verification.
