#!/bin/bash

# NetworkManager dispatcher script to handle dhcp4-change events
# for interfaces eth2 or eth3, extract wiit_vendor_fabric_ip, and update a connection called "fabric"
#
# Location: /etc/NetworkManager/dispatcher.d/10-fabric-ip-handler.sh
# Make executable with: chmod +x /etc/NetworkManager/dispatcher.d/10-fabric-ip-handler.sh
# Make sure owner is root: chown root:root /etc/NetworkManager/dispatcher.d/10-fabric-ip-handler.sh

INTERFACE="$1"
ACTION="$2"
FABRIC_CONNECTION="fabric"

# Log to syslog
echo "Called with interface=$INTERFACE, action=$ACTION"

# Exit if the action was triggered by the fabric interface
if [ "$INTERFACE" == "$FABRIC_CONNECTION" ]; then
    echo "Triggered by fabric interface, exiting"
    exit 1
fi

# Check if this is an "up" event
if [ "$ACTION" != "up" ]; then
    echo "Not an up event, exiting"
    exit 0
fi

if [ -z "$$CONNECTION_ID" ]; then
    echo "Could not find active connection for interface $INTERFACE"
    exit 1
fi

echo "Found active connection: $$CONNECTION_ID for interface $INTERFACE"

if [ -z "$DHCP4_WIIT_VENDOR_FABRIC_IP" ]; then
    echo "wiit_vendor_fabric_ip not found in DHCP options"
    exit 1
fi

# Get the current connection settings for prefix length and gateway
if [ -z "$DHCP4_WIIT_VENDOR_FABRIC_CIDR" ]; then
    echo "Fabric CIDR not set on switch, cannot update"
    exit 1
fi

# Check if the "fabric" connection exists
if ! nmcli connection show "$FABRIC_CONNECTION" &>/dev/null; then
    echo "Connection '$FABRIC_CONNECTION' does not exist, cannot update"
    exit 1
fi

# Check if the fabric ip is already set
if nmcli -t -f ipv4.addresses connection show "$FABRIC_CONNECTION" | grep $DHCP4_WIIT_VENDOR_FABRIC_IP; then
    echo "Fabric IP is already set, exiting"
    exit 0
fi

# Update the fabric connection with the new IP address
echo "Updating '$FABRIC_CONNECTION' connection with IP: $DHCP4_WIIT_VENDOR_FABRIC_IP"

# Update the connection IP address
nmcli connection modify "$FABRIC_CONNECTION" ipv4.addresses "$DHCP4_WIIT_VENDOR_FABRIC_IP/$DHCP4_WIIT_VENDOR_FABRIC_CIDR"

# Check if the connection update was successful
if [ $? -eq 0 ]; then
    echo "Successfully updated '$FABRIC_CONNECTION' connection"
    
    # Check if the connection is currently active
    if nmcli -t -f NAME,STATE connection show --active | grep -q "^$FABRIC_CONNECTION:activated"; then
        echo "Reapplying connection to activate new settings"
        nmcli connection up "$FABRIC_CONNECTION"
    fi
else
    echo "Failed to update '$FABRIC_CONNECTION' connection"
fi

exit 0