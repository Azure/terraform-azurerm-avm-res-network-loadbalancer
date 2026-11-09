package Azure_Proactive_Resiliency_Library_v2

import rego.v1

# The Global-tier frontend is an Anycast IP spanning regions, not a Regional
# zonal frontend. Follow Azure's cross-region quickstart, which omits zones
# on the Standard/Global IP:
# https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.network/load-balancer-cross-region/azuredeploy.json
# https://learn.microsoft.com/azure/load-balancer/cross-region-overview
# The current policy tests every tier for >=2 zones without a Global branch:
# https://github.com/Azure/policy-library-avm/blob/main/policy/Azure-Proactive-Resiliency-Library-v2/azapi/network/microsoft_network_publicIPAddresses.rego
#
# Conftest exceptions name a rule, not a resource. Guard this exception so
# EVERY other public IP must still meet that rule, and only the exact
# Standard/Global frontend with no configured zones may be exempted.
exception contains rules if {
    ips := [r |
        r := data.utils.resource(input, "azapi_resource")[_]
        data.utils.is_azure_type(r.values, "Microsoft.Network/publicIPAddresses")
    ]
    count(ips) == 3
    some global in ips
    global.address == "azapi_resource.public_ip[\"global\"]"
    global.values.body.sku == {"name": "Standard", "tier": "Global"}
    object.get(global.values.body, "zones", null) == null
    every r in ips {
        permitted_example_ip(r)
    }
    rules = ["use_standard_sku_and_zone_redundant_ip"]
}

permitted_example_ip(r) if {
    r.address == "azapi_resource.public_ip[\"global\"]"
    r.values.body.sku == {"name": "Standard", "tier": "Global"}
    object.get(r.values.body, "zones", null) == null
}

permitted_example_ip(r) if {
    r.values.body.sku.name == "Standard"
    r.values.body.sku.tier == "Regional"
    count(r.values.body.zones) >= 2
}
