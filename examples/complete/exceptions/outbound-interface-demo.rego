package Azure_Proactive_Resiliency_Library_v2

import rego.v1

# This non-production example exercises the module's supported outbound-rule
# interface. Removing outboundRules would remove that interface's runnable
# coverage. Production egress should use NAT Gateway as recommended by APRL:
# https://azure.github.io/Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/loadBalancers/#use-nat-gateway-instead-of-outbound-rules-for-production-workloads
# Exact AzAPI policy implementation:
# https://github.com/Azure/policy-library-avm/blob/main/policy/Azure-Proactive-Resiliency-Library-v2/azapi/network/microsoft_network_loadBalancers_outbound_rules.rego
exception contains rules if {
  rules = ["use_nat_gateway_instead_of_outbound_rules_for_production_load_balancer"]
}
