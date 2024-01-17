# linux-tools





# SNMP configuration

**Backup iptables rules and current snmpd.conf:**

    sudo tar -cvzf "snmpd-iptables-backup-$(date +%Y%m%d).tgz" /etc/snmp /etc/iptables/rules.v4    





**Add iptables firewall rules:**_

    sudo iptables -A INPUT -p tcp -m tcp --dport 161 -j ACCEPT

    sudo iptables -A INPUT -p udp -m udp --dport 161 -j ACCEPT





**Save iptables firewall rules:**

    sudo /usr/sbin/iptables-save | sudo tee /etc/iptables/rules.v4



**Edit snmp.conf:**

    sudo nano /etc/snmp/snmp.conf

    # mibs : # Comment out this line
    mibs ALL # Add this line
    # The rest of the file should be fine



**Edit snmpd.conf: (The following lines are an example configuration from my own lab, so please modify to your specific requirements.)**

    sudo nano /etc/snmp/snmpd.conf

    sysLocation     1110 Test St., Blah, CA          # Adjust to match appliance location
    sysContact      Dummy User dummy.user@domain.com # Adjust to match your support (team) name and email address
    sysServices     72                               # This should be fine as the default
    master  agentx                                   # This should be fine as the default
    agentaddress  127.0.0.1,_192.168.122.11_         # Make sure to add your own IP address here
    view   systemonly  included  .1.3.6.1.2.1        # This should replace what currently exists in the default configuration
    view   systemonly  included  .1.3.6.1.4.1        # This should replace what currently exists in the default configuration
    createuser superUser SHA-512 sha512passphrase AES aespassphrase    # Please adjust as desired
    rouser superUser authpriv -V systemonly          # Please adjust to match the user of your choosing




**OIDs for monitoring via SNMP:**

CPU Thread/Core Count:

    OID: 1.3.6.1.2.1.25.3.3.1.2


Per-CPU Load:

    OID: 1.3.6.1.2.1.25.3.3.1.2


Load Average 1 minute:

    OID: 1.3.6.1.4.1.2021.10.1.3.1


Load Average 5 minutes:

    OID: 1.3.6.1.4.1.2021.10.1.3.2


Load Average 15 minutes:

    OID: 1.3.6.1.4.1.2021.10.1.3.3


CPU Utilization:

    OID: 1.3.6.1.4.1.2021.11


Memory Installed:

    OID: 1.3.6.1.2.1.25.2.2.0


Memory In Use:

    OID: 1.3.6.1.4.1.2021.4.6.0


Memory Free:

    OID: 1.3.6.1.4.1.2021.4.11.0


Swap Partition Size:

    OID: 1.3.6.1.4.1.2021.4.3.0


Swap In Use:

    OID:1.3.6.1.4.1.2021.4.4.0


Swap Free:

    OID: 1.3.6.1.4.1.2021.4.5.0


Disks Installed:

    OID: 1.3.6.1.2.1.25.3.8


Partition Size for All Mounted Partitions:

    OID:1.3.6.1.2.1.25.2.3.1.5


Partition Mount Point:

    OID: 1.3.6.1.2.1.25.2.3.1.3


Partition Utilization:

    OID: 1.3.6.1.2.1.25.2.3.1.6


Total Size of a Storage Area:

    OID:1.3.6.1.2.1.25.2.3.1.5


Used Space of a Storage Area:

    OID:1.3.6.1.2.1.25.2.3.1.6


Running Processes:

    OID: 1.3.6.1.2.1.25.1.6.0


Network Interface Name:

    OID: 1.3.6.1.2.1.2.2.1.2


Network Interface IP Address:

    OID:1.3.6.1.2.1.4.20.1.2


Network Interface MAC Address:

    OID:1.3.6.1.2.1.2.2.1.6


Network interface index number (ifIndex):

    OID:1.3.6.1.2.1.2.2.1.1


Network interface Description (ifDescr):

    OID:1.3.6.1.2.1.2.2.1.2


Network interface bytes inbound (ifInOctets):

    OID:1.3.6.1.2.1.2.2.1.10


Network interface bytes outbound (ifOutOctets):

    OID:1.3.6.1.2.1.2.2.1.16


Network interface inbound errors (ifInErrors):

    OID:1.3.6.1.2.1.2.2.1.14


Network interface outbound errors (ifOutErrors):

    OID:1.3.6.1.2.1.2.2.1.20


Network interface operational status (ifOperStatus) (up/down):

    OID:1.3.6.1.2.1.2.2.1.8


Packets Received:

    OID: 1.3.6.1.2.1.2.2.1.11


Packets Sent: 

    OID: 1.3.6.1.2.1.2.2.1.17


SNMP Messages Received:

    OID:1.3.6.1.2.1.11.1


SNMP Messages Sent:

    OID:1.3.6.1.2.1.11.2


Logged in Users:

    OID: 1.3.6.1.2.1.25.1.5


Running Processes:

    OID: 1.3.6.1.2.1.25.4.2.1.2


Running Process Arguments:

    OID: 1.3.6.1.2.1.25.4.2.1.5


