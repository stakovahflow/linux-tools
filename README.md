# linux-tools





# SNMP configuration

**Backup iptables rules and current snmpd.conf:**

**_sudo tar -cvzf "snmpd-iptables-backup-$(date +%Y%m%d).tgz" /etc/snmp /etc/iptables/rules.v4_**





**Add iptables firewall rules:**_

**_sudo iptables -A INPUT -p tcp -m tcp --dport 161 -j ACCEPT_**

**_sudo iptables -A INPUT -p udp -m udp --dport 161 -j ACCEPT_**





**Save iptables firewall rules:**

**_sudo /usr/sbin/iptables-save | sudo tee /etc/iptables/rules.v4_**



**Edit snmp.conf:**

**_nano /etc/snmp/snmp.conf_**

# mibs : # Comment out this line

**mibs ALL** # Add this line

# The rest of the file should be fine



**Edit snmpd.conf: (The following lines are an example configuration from my own lab, so please modify to your specific requirements.)**

**_nano /etc/snmp/snmpd.conf_**

sysLocation    _1110 Test St., Blah, CA_          # Adjust to match appliance location

sysContact     _Dummy User dummy.user@domain.com_ # Adjust to match your support (team) name and email address

sysServices    72                               # This should be fine as the default

master  agentx                                  # This should be fine as the default

agentaddress  127.0.0.1,_192.168.122.11_          # Make sure to add your own IP address here

_view   systemonly  included  .1.3.6.1.2.1_       # This should replace what currently exists in the default configuration

_view   systemonly  included  .1.3.6.1.4.1_       # This should replace what currently exists in the default configuration

createuser _superUser_ SHA-512 _sha512passphrase_ AES _aespassphrase_ # Please adjust as desired

rouser _superUser_ authpriv -V systemonly         # Please adjust to match the user of your choosing





**OIDs for monitoring via SNMP:**

CPU Thread/Core Count: 

_OID: 1.3.6.1.2.1.25.3.3.1.2_



 

Per-CPU Load: 

_OID: 1.3.6.1.2.1.25.3.3.1.2_



 

Load Average 1 minute: 

_OID: 1.3.6.1.4.1.2021.10.1.3.1_



 

Load Average 5 minutes: 

_OID: 1.3.6.1.4.1.2021.10.1.3.2_



 

Load Average 15 minutes: 

_OID: 1.3.6.1.4.1.2021.10.1.3.3_



 

CPU Utilization: 

_OID: 1.3.6.1.4.1.2021.11_



 

Memory Installed: 

_OID: 1.3.6.1.2.1.25.2.2.0_



 

Memory In Use: 

_OID: 1.3.6.1.4.1.2021.4.6.0_



 

Memory Free: 

_OID: 1.3.6.1.4.1.2021.4.11.0_



 

Swap Partition Size: 

_OID: 1.3.6.1.4.1.2021.4.3.0_



 

Swap In Use:

_OID: 1.3.6.1.4.1.2021.4.4.0_



 

Swap Free: 

_OID: 1.3.6.1.4.1.2021.4.5.0_



 

Disks Installed: 

_OID: 1.3.6.1.2.1.25.3.8_



 

Partition Size for All Mounted Partitions:

_OID: 1.3.6.1.2.1.25.2.3.1.5_



 

Partition Mount Point: 

_OID: 1.3.6.1.2.1.25.2.3.1.3_



 

Partition Utilization: 

_OID: 1.3.6.1.2.1.25.2.3.1.6_



 

Total Size of a Storage Area:

_OID: 1.3.6.1.2.1.25.2.3.1.5_



 

Used Space of a Storage Area:

_OID: 1.3.6.1.2.1.25.2.3.1.6_



 

Running Processes: 

_OID: 1.3.6.1.2.1.25.1.6.0_



 

Network Interface Name: 

_OID: 1.3.6.1.2.1.2.2.1.2_



 

Network Interface IP Address:

_OID: 1.3.6.1.2.1.4.20.1.2_



 

Network Interface MAC Address:

_OID: 1.3.6.1.2.1.2.2.1.6_



 

Network interface index number (ifIndex):

_OID: 1.3.6.1.2.1.2.2.1.1_



 

Network interface Description (ifDescr):

_OID: 1.3.6.1.2.1.2.2.1.2_



 

Network interface bytes inbound (ifInOctets):

_OID: 1.3.6.1.2.1.2.2.1.10_



 

Network interface bytes outbound (ifOutOctets):

_OID: 1.3.6.1.2.1.2.2.1.16_



 

Network interface inbound errors (ifInErrors):

_OID: 1.3.6.1.2.1.2.2.1.14_



 

Network interface outbound errors (ifOutErrors):

_OID: 1.3.6.1.2.1.2.2.1.20_



 

Network interface operational status (ifOperStatus) (up/down):

_OID: 1.3.6.1.2.1.2.2.1.8_



 

Packets Received: 

_OID: 1.3.6.1.2.1.2.2.1.11_



 

Packets Sent: 

_OID: 1.3.6.1.2.1.2.2.1.17_



 

SNMP Messages Received:

_OID: 1.3.6.1.2.1.11.1_



 

SNMP Messages Sent:

_OID: 1.3.6.1.2.1.11.2_



 

Logged in Users:

_OID:  1.3.6.1.2.1.25.1.5_



 

Running Processes:

_OID:  1.3.6.1.2.1.25.4.2.1.2_



 

Running Process Arguments:

_OID:  1.3.6.1.2.1.25.4.2.1.5_



