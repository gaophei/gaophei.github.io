I'll help you with both tasks: changing the SCAN IP address in Oracle 11g RAC and configuring a second IP address on CentOS 7.9.

## Changing SCAN IP Address in Oracle 11g RAC

### Step 1: Check Current SCAN Configuration

First, verify the current SCAN configuration:

```bash
# As grid user
srvctl config scan
srvctl status scan
nslookup <scan_name>
```

### Step 2: Stop SCAN Resources

```bash
# As grid user
srvctl stop scan_listener
srvctl stop scan
```

### Step 3: Modify SCAN IP Address

```bash
# As root user
# First, update DNS or /etc/hosts file to reflect new IP (172.18.55.4)
vi /etc/hosts
# Change the SCAN entry from 172.18.55.6 to 172.18.55.4


/u01/app/11.2.0/grid/bin/srvctl modify scan -n rac-scan

#如果失败，执行以下步骤
# As grid user
# Remove old SCAN configuration
srvctl remove scan -force

# Add new SCAN configuration
srvctl add scan -n <scan_name>
# The SCAN name should match what's in DNS/hosts file

# Recreate SCAN listeners
srvctl add scan_listener -p <port>
# Usually port 1521
```

### Step 4: Start SCAN Resources

```bash
# As grid user
srvctl start scan
srvctl start scan_listener

# Verify the changes
srvctl config scan
srvctl status scan
```

### Step 5: Update Remote/Local Listener Parameters

```sql
-- As SYS user in SQL*Plus
ALTER SYSTEM SET remote_listener='<scan_name>:<port>' SCOPE=BOTH SID='*';
ALTER SYSTEM REGISTER;
```

## Adding Second IP Address on CentOS 7.9

You have several options for adding a second IP. Here are the two most common methods:

### Method 1: Using Network Interface Alias (Traditional)

1. **Create an alias configuration file:**

```bash
# Assuming your primary interface is eth0 or ens33
# Check your interface name first
ip addr show

# Create alias configuration
sudo vi /etc/sysconfig/network-scripts/ifcfg-eth0:0
# Or ifcfg-ens33:0 depending on your interface name
```

1. **Add the following content:**

```bash
DEVICE=eth0:0
BOOTPROTO=static
IPADDR=172.18.55.6
NETMASK=255.255.255.0
ONBOOT=yes
```

1. **Activate the interface:**

```bash
sudo ifup eth0:0
# Or
sudo systemctl restart network
```

### Method 2: Using NetworkManager (Recommended for CentOS 7.9)

1. **Add secondary IP to existing connection:**

```bash
# First, identify your connection name
nmcli connection show

# Add the secondary IP (replace 'System eth0' with your connection name)
sudo nmcli connection modify "System eth0" +ipv4.addresses "172.18.55.6/24"

# Apply the changes
sudo nmcli connection up "System eth0"
```

1. **Verify the configuration:**

```bash
ip addr show
# You should see both IP addresses on the interface
```

### Method 3: Using ip command (Temporary)

For testing purposes (non-persistent):

```bash
sudo ip addr add 172.18.55.6/24 dev eth0
```

## Important Considerations

1. **Oracle Listener Configuration**: After changing IPs, update the Oracle listener configuration on the single instance to listen on 172.18.55.6:

```bash
# Edit listener.ora
vi $ORACLE_HOME/network/admin/listener.ora

# Add/modify:
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = 172.18.55.6)(PORT = 1521))
    )
  )
```

1. **Firewall Rules**: Update firewall rules if needed:

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.18.55.0/24" port protocol="tcp" port="1521" accept'
sudo firewall-cmd --reload
```

1. **Testing**: After making changes:

- Test SCAN connectivity: `tnsping <scan_name>`
- Test new IP connectivity: `ping 172.18.55.6`
- Verify Oracle services are accessible on both systems

1. **Client Connection Strings**: Update any client tnsnames.ora files to use the new SCAN IP address.

Would you like me to elaborate on any of these steps or help with troubleshooting if you encounter issues?