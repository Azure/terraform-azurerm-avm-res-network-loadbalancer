# Backend address pool

Manages one pool, its IP-based backend addresses and Gateway tunnel interfaces.
The caller owns cardinality. NIC membership belongs to the NIC-owning module.
NIC references are omitted from writes; live preservation is not Azure-verified.
IP-based addresses are authoritative.

**Draft standalone module.** The root LB does not compose this module. Do not
use it against an LB whose root configuration owns the same inline pools:
that would introduce conflicting ownership. It is not a workaround for the
root's outstanding composition design gate.
