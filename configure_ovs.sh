#!/bin/bash

# Config settings
NSXMANAGER="10.10.10.10"
VLANPUB=10
VLANTRANS=20
VLANMGT=30

echo "Welcome to Open vSwitch config script."
 
# Bridges
echo "Agree to create cloudbr0 and cloubbr1? (y/n)"
read cloudbrans
if [ "$cloudbrans" = y ]; then
  echo "You said yes."
  echo "Creating bridges cloudbr0 and cloudbr1.."
  ovs-vsctl add-br cloudbr0
  ovs-vsctl add-br cloudbr1
else
  echo "You said no."
fi
 
# Get interfaces
IFACES=$(ls /sys/class/net | grep -E '^em|^eno|^eth|^p2' | tr '\n' ' ')
 
echo "Network interfaces on system: $IFACES"
IFACEUP=""
 
# See what links are up
for i in $IFACES
  do
    ethtool $i | grep -q "Link detected: yes"
  if [ $? -eq 0 ]; then
     IFACEUP="$IFACEUP $i" 
  fi
done
 
echo "Interfaces that have their links UP: $IFACEUP"
 
# Bonds
echo "Do you want to create a bond with interfaces $IFACEUP? (y/n)"
read createbondans
if [ "$createbondans" = y ]; then
  echo "You said yes."
  # Create Bond
  echo "Creating bond with $IFACEUP"
  ovs-vsctl add-bond cloudbr0 bond0 $IFACEUP bond_mode=balance-tcp lacp=active other_config:lacp-time=fast
else
  echo "You said no."
fi
 
echo "Do you want to create a bond with interfaces $IFACES? (y/n)"
read createbondans
if [ "$createbondans" = y ]; then
  echo "You said yes."
  # Create Bond
  echo "Creating bond with $IFACES"
  ovs-vsctl add-bond cloudbr0 bond0 $IFACES bond_mode=balance-tcp lacp=active other_config:lacp-time=fast
else
  echo "You said no."
fi
 
# Integration bridge
echo "Do you want to create the integration bridge br-int? (y/n)"
read brintans
if [ "$brintans" = y ]; then
  echo "You said yes."
  echo "Creating NVP integration bridge br-int"
  ovs-vsctl -- --may-exist add-br br-int\
            -- br-set-external-id br-int bridge-id br-int\
            -- set bridge br-int other-config:disable-in-band=true\
            -- set bridge br-int fail-mode=secure
else
  echo "You said no."
fi
 
# Fake bridges
echo "Do you want to create the fake bridges, mgmt0 trans0 and pub0? (y/n)"
read fakeans
if [ "$fakeans" = y ]; then
  echo "You said yes."
  echo "Create fake bridges"
  ovs-vsctl add-br mgmt0 cloudbr0 $VLANMGT
  ovs-vsctl add-br trans0 cloudbr0 $VLANTRANS
  ovs-vsctl add-br pub0 cloudbr0 $VLANPUB
else
  echo "You said no."
fi
 
# Get OS type
if [ -f /etc/os-release ]; then
  source /etc/os-release
  echo "Detected OS: $ID"
else
  echo "Error: Could not detect OS: Only tested on Ubuntu 14.04/14.10/15.04 and CentOS 7."
  exit;
fi

echo "Do you want to write network configuration? (y/n)"
read netans
if [ "$netans" = y ]; then
  echo "You said yes."
 
case $ID in
    "ubuntu")
         echo "Processing $ID"
echo "auto cloudbr0
allow-ovs cloudbr0
iface cloudbr0 inet dhcp
   ovs_type OVSIntPort
 
auto trans0
allow-ovs trans0
iface trans0 inet dhcp
   ovs_type OVSIntPort
" > /etc/network/interfaces
 
for i in $IFACES
  do echo "Configuring $i..."
echo "auto $i
iface $i inet manual
" >> /etc/network/interfaces
done
    ;;
    "centos")
echo "Processing $ID"
 
# Physical interfaces
for i in $IFACES
  do echo "Configuring $i..."
  echo "DEVICE=$i
ONBOOT=yes
NETBOOT=yes
IPV6INIT=no
BOOTPROTO=none
NM_CONTROLLED=no
" > /etc/sysconfig/network-scripts/ifcfg-$i
done
 
# Config cloudbr0
echo "Configuring cloubbr0"
echo "DEVICE=\"cloudbr0\"
ONBOOT=yes
DEVICETYPE=ovs
TYPE=OVSIntPort
BOOTPROTO=dhcp
HOTPLUG=no
" > /etc/sysconfig/network-scripts/ifcfg-cloudbr0
 
# Config trans0
echo "Configuring trans0"
echo "DEVICE=\"trans0\"
ONBOOT=yes
DEVICETYPE=ovs
TYPE=OVSIntPort
BOOTPROTO=dhcp
HOTPLUG=no
" > /etc/sysconfig/network-scripts/ifcfg-trans0

# Config bond0 
echo "Configuring bond0"
echo "DEVICE=\"bond0\"
ONBOOT=yes
DEVICETYPE=ovs
TYPE=OVSBond
OVS_BRIDGE=cloudbr0
BOOTPROTO=none
BOND_IFACES=\"$IFACES\"
OVS_OPTIONS="bond_mode=balance-tcp lacp=active other_config:lacp-time=fast"
HOTPLUG=no
" > /etc/sysconfig/network-scripts/ifcfg-bond0
    ;;
    *)
    echo "Unsupported OS " $ID
    exit
    ;;
esac
 
else
  echo "You said no."
fi
 
echo "Do you want to generate new OVS SSL certificates? (y/n)"
read sslans
if [ "$sslans" = y ]; then
  echo "You said yes."
  echo "Generate OVS certificates"
  cd /etc/openvswitch
  ovs-pki req ovsclient
  ovs-pki self-sign ovsclient
  ovs-vsctl -- --bootstrap set-ssl \
            "/etc/openvswitch/ovsclient-privkey.pem" "/etc/openvswitch/ovsclient-cert.pem"  \
            /etc/openvswitch/vswitchd.cacert
else
  echo "You said no."
fi
 
echo "Do you want to connect to the NSX controller at $NSXMANAGER? (y/n)"
read managerans
if [ "$managerans" = y ]; then
  echo "You said yes."
  echo "Point manager to NSX controller"
  ovs-vsctl set-manager ssl:$NSXMANAGER:6632
else
  echo "You said no."
fi
 
echo "Done. Don't forget to enable both interfaces on the switches. First do a reboot, check if all is OK, then add this host to NSX."
