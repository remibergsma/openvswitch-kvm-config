# Generate Open vSwitch config for KVM/CloudStack
This is a script to setup Open vSwitch networking for a KVM hypervisor running on Ubuntu (14.04/14.10/15.04) or CentOS 6 and 7.

It was used in a lab where we compared different OS'es and had to setup Open vSwitch networking a lot of times.

What it does:
- create cloudbr0 and cloudbr1 used by CloudStack
- looks for network interface cards and created an LACP bond with them
- create mgmt0, trans0 and pub0 fake bridges, each on an own vlan (configurable)
- write network config to be persistent across reboots
- generate Open vSwitch SSL certificates
- connect to a OVS controller/manager (configurable)
 
If you use this, install KVM and the CloudStack agent, you'll be add the hypervisor right away.
