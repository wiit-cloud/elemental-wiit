#!/usr/bin/env bash

# NetworkManager dispatcher script to handle hostname-change events
# Updates /etc/hosts with the new hostname received from DHCP
#
# Location: /etc/NetworkManager/dispatcher.d/10-hostname-handler.sh
# Make executable with: chmod +x /etc/NetworkManager/dispatcher.d/10-hostname-handler.sh
# Make sure owner is root: chown root:root /etc/NetworkManager/dispatcher.d/10-hostname-handler.sh

set -x

INTERFACE="$1"
ACTION="$2"
HOSTS_FILE="/etc/hosts"

# Exit if the action is not a hostname change
if [ "$ACTION" != "hostname" ]; then
    exit 0
fi

# Log to stdout (captured by nm-dispatcher into syslog)
echo "Called with action=$ACTION"

# Get the new hostname from the system
NEW_HOSTNAME=$(hostname 2>/dev/null || echo "")
NEW_FQDN=$(hostname -f 2>/dev/null || echo "")

echo "Currently known: hostname $NEW_HOSTNAME and fqdn $NEW_FQDN"
echo mlx0: $(nmcli -f DHCP4.OPTIONS device show mlx0 | egrep "\s(host_name|domain_name)\s")
echo mlx1: $(nmcli -f DHCP4.OPTIONS device show mlx1 | egrep "\s(host_name|domain_name)\s")

# Check if /etc/hosts exists
if [ ! -f "$HOSTS_FILE" ]; then
    echo "$HOSTS_FILE does not exist" >&2
    exit 1
fi

# Backup original hosts file
if ! cp /etc/hosts /etc/hosts.bak; then
    echo "Could not create backup of $HOSTS_FILE"
    exit 1
fi

# Update hosts file, by simply replacing the full line for localhost
if ! sed -i -E "s|^(127\.0\.0\.1)\s+.*$|\1\t$NEW_FQDN $NEW_HOSTNAME localhost localhost.localdomain|g" "$HOSTS_FILE"; then
    echo "Failed to update $HOSTS_FILE" >&2
    exit 1
fi

if ! sed -i -E "s|^(::1)\s+.*$|\1\t$NEW_FQDN $NEW_HOSTNAME localhost localhost.localdomain ipv6-localhost ipv6-loopback|g" "$HOSTS_FILE"; then
    echo "Failed to update $HOSTS_FILE" >&2
    exit 1
fi

echo "Successfully updated hostname to '$NEW_HOSTNAME' in $HOSTS_FILE"
exit 0