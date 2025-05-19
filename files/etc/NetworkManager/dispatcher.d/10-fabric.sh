#!/bin/bash

# NetworkManager dispatcher script to handle dhcp4-change events
# for interfaces eth2 or eth3, extract wiit_vendor_fabric_ip, and update a connection called "fabric"
#
# Location: /etc/NetworkManager/dispatcher.d/10-fabric-ip-handler.sh
# Make executable with: chmod +x /etc/NetworkManager/dispatcher.d/10-fabric-ip-handler.sh
# Make sure owner is root: chown root:root /etc/NetworkManager/dispatcher.d/10-fabric-ip-handler.sh

INTERFACE="$1"
ACTION="$2"
TARGET_INTERFACES=("eth2" "eth3")
FABRIC_CONNECTION="fabric"
CONNECTION_NAME=""

# Log to syslog
logger -t "fabric-ip-handler" "Called with interface=$INTERFACE, action=$ACTION"

# Check if this is one of our target interfaces
INTERFACE_MATCH=0
for TARGET_INTERFACE in "${TARGET_INTERFACES[@]}"; do
    if [ "$INTERFACE" == "$TARGET_INTERFACE" ]; then
        INTERFACE_MATCH=1
        break
    fi
done

if [ $INTERFACE_MATCH -eq 0 ]; then
    logger -t "fabric-ip-handler" "Not one of our target interfaces (${TARGET_INTERFACES[*]}), exiting"
    exit 0
fi

# Check if this is a dhcp4-change event
if [ "$ACTION" != "dhcp4-change" ]; then
    logger -t "fabric-ip-handler" "Not a dhcp4-change event, exiting"
    exit 0
fi

# Get active connection name for this interface
CONNECTION_NAME=$(nmcli -t -f NAME,DEVICE connection show --active | grep ":$INTERFACE" | cut -d: -f1)

if [ -z "$CONNECTION_NAME" ]; then
    logger -t "fabric-ip-handler" "Could not find active connection for interface $INTERFACE"
    exit 1
fi

logger -t "fabric-ip-handler" "Found active connection: $CONNECTION_NAME for interface $INTERFACE"

# Get the wiit_vendor_fabric_ip value using nmcli
FABRIC_IP=$(nmcli -t -f DHCP4.OPTION connection show "$CONNECTION_NAME" | grep "wiit_vendor_fabric_ip" | cut -d= -f2 | tr -d ' ')

if [ -z "$FABRIC_IP" ]; then
    logger -t "fabric-ip-handler" "wiit_vendor_fabric_ip not found in DHCP options"
    exit 1
fi

# Check if the "fabric" connection exists
if ! nmcli connection show "$FABRIC_CONNECTION" &>/dev/null; then
    logger -t "fabric-ip-handler" "Connection '$FABRIC_CONNECTION' does not exist, cannot update"
    exit 1
fi

# Update the fabric connection with the new IP address
logger -t "fabric-ip-handler" "Updating '$FABRIC_CONNECTION' connection with IP: $FABRIC_IP"

# Get the current connection settings for prefix length and gateway
CURRENT_PREFIX=$(nmcli -t -f ipv4.addresses connection show "$FABRIC_CONNECTION" | cut -d: -f2 | grep -o '/[0-9]*' | tr -d '/')
if [ -z "$CURRENT_PREFIX" ]; then
    # Default to /32 if no prefix is found
    CURRENT_PREFIX="32"
    logger -t "fabric-ip-handler" "No prefix found, using default: $CURRENT_PREFIX"
else
    logger -t "fabric-ip-handler" "Using existing prefix: $CURRENT_PREFIX"
fi

# Update the connection IP address
nmcli connection modify "$FABRIC_CONNECTION" ipv4.addresses "$FABRIC_IP/$CURRENT_PREFIX"

# Check if the connection update was successful
if [ $? -eq 0 ]; then
    logger -t "fabric-ip-handler" "Successfully updated '$FABRIC_CONNECTION' connection"
    
    # Check if the connection is currently active
    if nmcli -t -f NAME,STATE connection show --active | grep -q "^$FABRIC_CONNECTION:activated"; then
        logger -t "fabric-ip-handler" "Reapplying connection to activate new settings"
        nmcli connection up "$FABRIC_CONNECTION"
    fi
else
    logger -t "fabric-ip-handler" "Failed to update '$FABRIC_CONNECTION' connection"
fi

exit 0