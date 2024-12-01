#!/bin/bash
# eyeInspect-health-check
# Updated: Allen Sowell
EIHCversion='2024-12-01-a'

currentdir=$(pwd)
cd /tmp

# description:
# gathers system information, network information, and logs from a SilentDefense appliance
#	adjusts for use on a sensor or a command center
#	this is not comprehensive, feel free to add more

# script input:
# Command Center Address
# CC Web Admin Username
# CC Web Admin Password

# script output:
# a tar.gz file containing both the created and gathered log files - for transfer off the machine
# a folder with the same files for immediate viewing

if [[ "$(whoami)" != 'root' ]]; then
	echo -e "Please run as root ($0 <options>)"
	exit
fi

# Set some global variables:
i=1
DATED=$(date +%Y%m%d)
HOSTNAME=$(hostname)
EIHCLOGS="EIHC-Logs-$HOSTNAME-$DATED"
LOGDIR="/tmp/$EIHCLOGS"
TOMCATLOGDIR="$LOGDIR/tomcat"
TARBALL="$currentdir/$EIHCLOGS.tar.gz"
QUERYCMD='sudo -u postgres psql -P pager=off -q -d silentdefense -v ON_ERROR_STOP=1 -c'
CCADDRESS=''
USERNAME=''
USERPASS=''

BREAK() {
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '#'
}
LINE() {
	printf '\n%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '#'
}
padded (){
	printf '%s/%02d_%s_%s' "$LOGDIR" "$1" "$HOSTNAME" "$2"
}

SPINNER (){
	PID=$!
	x=1
	sp="/-\|"
	while [ -d /proc/$PID ]
		do
			printf "\b${sp:x++%${#sp}:1}"
		done
	printf "\b "
	echo -e ""
}

# Python script: /usr/local/bin/sensorhealth
sensorCheck(){
tmpsensorhealth=$(mktemp -p /tmp)
echo "Created $tmpsensorhealth to perform sensor health-check via API"

cat << "----END" > $tmpsensorhealth

#!/usr/bin/env python3
from ipaddress import ip_address
import requests, os, sys, json, ssl, time, argparse, csv, getpass, subprocess
from re import search
from collections import OrderedDict
from datetime import date
from requests.packages.urllib3.exceptions import InsecureRequestWarning
t = time.localtime()
current_time = time.strftime('%H-%M-%S', t)
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
today = date.today()
itl_modules = []
# Textual month, day and year
fmt_today = today.strftime('%Y-%m-%d')+'-'+current_time
CSV_HEADER = ['name','id', 'sensor_version','state', 'lastupdate']
API_SENSORS = 'https://{}/api/v1/sensors?offset={}&limit={}'
API_SENSORS_MODULES='https://{}/api/v1/sensors/{}/modules'
API_SENSORS_MODULES_DL='https://{}/api/v1/sensors/{}/modules/{}'
sheet=[]
#-----------------------------------------------------------------------------------------
parser = argparse.ArgumentParser(description='Creates and saves a report of the itl_modules')
parser.add_argument('-c', '--cc_address', type=str, help='eyeInspect CC hostname/IP')
parser.add_argument('-u', '--user', type=str, help='eyeInspect username')
parser.add_argument('-p', '--password', type=str, help='eyeInspect password')
parser.add_argument('-o', '--output', type=str, help='Sensor Data Output filename')
parser.add_argument('-m', '--moduleout', type=str, help='Sensor Module Output filename')
parser.add_argument('--source_id', type=str, help='sensor to use as source')
parser.add_argument('--offset', type=str, help='Fetch records starting from the given offset (minimum is 0).Default is 0.',default='0')
parser.add_argument('--limit', type=str, help='Fetch only up to limit records. Default is 200',default='200')
parser.add_argument('--timeout', type=int, help='Time before upload of the api requests.Default 60 sec',default=60)
args=parser.parse_args()

if args.cc_address:
	cc_address=args.cc_address
else:
	cc_address='127.0.0.1'
if args.user:
	user=args.user
else:
	user='admin'
if args.password:
	pw=args.password
else:
	pw='password'
if args.output:
	outfile=args.output
else:
	outfile='sensordata.csv'
if args.moduleout:
	modoutfile=args.moduleout
else:
	modoutfile='moduledata.csv'
#------------------------------------------------------------------------------------------
try:
	url_sensors = API_SENSORS.format(cc_address,args.offset,args.limit)
except:
	print('Unable to set sensor query string')
	exit(0)
try:
	url_sensors_api_call = requests.get(url_sensors, verify=False, auth=(user,pw ),timeout=30)
except:
	print('Unable to query API')
	exit(0)

try:
	sensors_json = url_sensors_api_call.json()
	total_count = int(sensors_json['total_count'])
	with open(outfile, 'w') as f:
		write=csv.writer(f, quotechar="\"")
		sensors = sensors_json['results']
		sheet.append('Sensor:')
		sheet.append('ID:')
		sheet.append('Address:')
		sheet.append('Version:')
		sheet.append('Type:')
		sheet.append('Port:')
		sheet.append('Status:')
		sheet.append('CPU (1 Minute Average):')
		sheet.append('CPU Percent:')
		sheet.append('Memory:')
		sheet.append('Memory Percent:')
		sheet.append('Throughput Level:')
		sheet.append('Throughput Speed:')
		sheet.append('Dropped Packet Level:')
		sheet.append('Dropped Packets:')
		sheet.append('Disk:')
		sheet.append('Disk Status:')
		sheet.append('Disk Usage:')
		sheet.append('NIDS State:')
		sheet.append('Timezone:')
		sheet.append('Timezone Path:')
		sheet.append('Licensing')
		sheet.append('Reversed')
		sheet.append('Network Interface(s):')
		sheet.append('Interface Status(es):')
		sheet.append('Interface Value(s):')
		write.writerow(sheet)
		for sensor in sensors:
			#print("%s" % (sensor))
			csvline=[]
			interfaces=[]
			intstatus=[]
			intvalue=[]
			url_sensors_modules = API_SENSORS_MODULES.format(
								cc_address,sensor['id']
							)
			try:
				SENSORNAME=(sensor['name'])
			except:
				SENSORNAME=""
			try:
				SENSORID=(sensor['id'])
			except:
				SENSORID=""
			try:
				SENSORADDR=(sensor['address'])
			except:
				SENSORADDR=""
			try:
				SENSORVER=(sensor['sensor_version'])
			except:
				SENSORVER=""
			try:
				SENSORTYPE=(sensor['type'])
			except:
				SENSORTYPE=""
			try:
				SENSORPORT=(sensor['port'])
			except:
				SENSORPORT=""
			try:
				SENSORSTATE=(sensor['state'])
			except:
				SENSORSTATE=""
			try:
				SENSORCPULOAD=(sensor['health_status']['cpu_load_avg_1_min']['level'])
			except:
				SENSORCPULOAD=""
			try:
				SENSORCPUPERCENT=(sensor['health_status']['cpu_load_avg_1_min']['current_value'])
			except:
				SENSORCPUPERCENT=""
			try:
				SENSORMEMLEVEL=(sensor['health_status']['memory_usage']['level'])
			except:
				SENSORMEMLEVEL=""
			try:
				SENSORMEMUAGE=(sensor['health_status']['memory_usage']['current_value'])
			except:
				SENSORMEMUAGE=""
			try:
				SENSORTHRULEVEL=(sensor['health_status']['throughput']['level'])
			except:
				SENSORTHRULEVEL=""
			try:
				SENSORTHRUVALUE=(sensor['health_status']['throughput']['current_value'])
			except:
				SENSORTHRUVALUE=""
			try:
				DROPPEDPKTLEVEL=(sensor['health_status']['dropped_packets']['level'])
			except:
				DROPPEDPKTLEVEL=""
			try:
				DROPPEDPKTVALUE=(sensor['health_status']['dropped_packets']['current_value'])
			except:
				DROPPEDPKTVALUE=""
			csvline.append(SENSORNAME)
			csvline.append(SENSORID)
			csvline.append(SENSORADDR)
			csvline.append(SENSORVER)
			csvline.append(SENSORTYPE)
			csvline.append(SENSORPORT)
			csvline.append(SENSORSTATE)
			csvline.append(SENSORCPULOAD)
			csvline.append(SENSORCPUPERCENT)
			csvline.append(SENSORMEMLEVEL)
			csvline.append(SENSORMEMUAGE)
			csvline.append(SENSORTHRULEVEL)
			csvline.append(SENSORTHRUVALUE)
			csvline.append(DROPPEDPKTLEVEL)
			csvline.append(DROPPEDPKTVALUE)
			zoneinfo=[]
			nidsstate=[]
			licensing=[]
			reversedconn=[]
			for disk in (sensor['health_status']['disk_usage']):
				rootspace=[]
				nidsstate=[]
				zoneinfo=[]
				try:
					if disk['name']=='/':
						try:
							rootspace.append(disk['name'])
						except:
							rootspace.append("")
						try:
							rootspace.append(disk['level'])
						except:
							rootspace.append("")
						try:
							rootspace.append(disk['current_value'])
						except:
							rootspace.append("")
				except Exception as e:
					print('Exception occurred: %s' % (e))
				for rootattribute in rootspace:
					csvline.append(rootattribute)
				try:
					if search ('/usr/share/zoneinfo',disk['name']):
						try:
							csvline.append(disk['name'])
						except:
							csvline.append("")
				except Exception as e:
					print('Exception occurred: %s' % (e))
				for zoneattribute in zoneinfo:
					csvline.append(zoneattribute)
				try:
					if search ('/opt/nids/state',disk['name']):
						nidsstate.append(disk['level'])
					for nidsattribute in nidsstate:
						csvline.append(nidsattribute)
				except Exception as e:
					print('Exception occurred: %s' % (e))
			try:
				csvline.append(sensor['health_status']['license_status']['level'])
			except Exception as e:
				print('Exception occurred: %s' % (e))
				csvline.append("")
			try:
				csvline.append(sensor['health_status']['license_status']['current_value'])
			except Exception as e:
				print('Exception occurred: %s' % (e))
				csvline.append("")
			try:
				csvline.append(sensor['is_reversed_conn'])
			except Exception as e:
				print('Exception occurred: %s' % (e))
				csvline.append("")
			try:
				for iface in (sensor['health_status']['net_if_status']):
					try:
						interfaces.append(iface['name'])
					except:
						interfaces.append("")
					try:
						intstatus.append(iface['level'])
					except:
						intstatus.append("")
					try:
						intvalue.append(iface['current_value'])
					except:
						intvalue.append("")
			except Exception as e:
				print('Exception occurred: %s' % (e))
			csvline.append(interfaces)
			csvline.append(intstatus)
			csvline.append(intvalue)
			write.writerow(csvline)
	f.close()
except Exception as e:
	print('Exception occurred: %s' % (e))
try:
	with open(modoutfile, 'w') as f:
		write=csv.writer(f, quotechar="\"")
		try:
			modexport=[]
			modexport.append('Sensor')
			modexport.append('ID')
			modexport.append('Engine')
			modexport.append('Name')
			modexport.append('Started')
			modexport.append('Operational Mode')
			modexport.append('Last Updated')
			write.writerow(modexport)
			for sensor in sensors:
				url_sensors_modules = API_SENSORS_MODULES.format(
									cc_address,sensor['id']
								)
				url_sensors_modules_api_call = requests.get(url_sensors_modules, verify=False, auth=(user,pw ),timeout=args.timeout)
				for module in url_sensors_modules_api_call.json()['results']:
					try:
						SENSORNAME=sensor['name']
					except:
						SENSORNAME=""
					try:
						SENSORID=sensor['id']
					except:
						SENSORID=""
					try:
						MODENGINE=module['engine']
					except:
						MODENGINE=""
					try:
						MODNAME=module['name']
					except:
						MODNAME=""
					try:
						MODSTART=module['started']
					except:
						MODSTART=""
					try:
						MODMODE=module['operational_mode']
					except:
						MODMODE=""
					try:
						MODUPDATED=module['date_last_update']
					except:
						MODUPDATED=""
					try:
						modexport=[]
						modexport.append(SENSORNAME)
						modexport.append(SENSORID)
						modexport.append(MODENGINE)
						modexport.append(MODNAME)
						modexport.append(MODSTART)
						modexport.append(MODMODE)
						modexport.append(MODUPDATED)
						write.writerow(modexport)
					except:
						print("Exception occurred producing Modules list: \n%s" % (e))
		except Exception as e:
			print('Exception occurred: %s' % (e))
	f.close()
except Exception as e:
	print("Exception occurred: %s" % (e))
----END
chmod a+x $tmpsensorhealth
}

###########################################################################
# system info log:
if [[ -d "$LOGDIR" ]]; then
	rm -rf "$LOGDIR"
fi

if [[ -f "$TARBALL" ]]; then
	rm -rf "$TARBALL"
fi

mkdir -p "$LOGDIR"
chmod 777 "$LOGDIR"

# Main log:
mainlog=$(padded $i "Main.log"); ((i++))
echo -e "Healthcheck Version: $EIHCversion"

OS_VERSION=$(grep "^VERSION=" /etc/os-release | cut -d "=" -f 2 | tr -d "\"")
cc_installed=$(apt-cache pkgnames | grep silentdefense-cc-core)
sensor_installed=$(apt-cache pkgnames | grep silentdefense-nids)
SENSORHEALTH=false
SYSTEMINFO=$(dmidecode | grep -A 9 "^System Information" | grep -v "^System Information" | sed 's/^\t/\t\t/g')
CCADDRESS="127.0.0.1"

if [ -n "$cc_installed" ]; then
	LINE
	# Create sensorCheck script and execute with username & password information provided
	echo -e "Creating Sensor Healthcheck API Script"
	sensorCheck
	###########################################################################
	# Get CC Address, Admin Username, Admin Pasword from user input:
	#IFS= read -rp $'Command Center Address: ' CCADDRESS
	IFS= read -rp $'CC Web Admin Username: ' USERNAME
	IFS= read -rsp $'CC Web Admin Password: ' USERPASS
	LINE
fi

if [ -z "$CCADDRESS" ]; then
	echo -e "Skipping Sensor Health Component: No Command Center Specified" | tee -a "$mainlog"
else
	if [ -z "$USERNAME" ]; then
		echo -e "Skipping Sensor Health Component: No Web Username Specified" | tee -a "$mainlog"
	else
		if [ -z "$USERPASS" ]; then
			echo -e "Skipping Sensor Health Component: No Password Specified" | tee -a "$mainlog"
		else
			SENSORHEALTH=true
		fi
	fi
fi

ifcon="$(ifconfig -a)"
ip=$(echo -e "$ifcon" |grep "inet" |sed -e 's/^[ \t]*//' |head -n 1 |awk '{ print $2 }' |cut -d ":" -f 2)
ips=$(echo -e "$ifcon" |grep "inet" |sed -e 's/^[ \t]*//' |awk '{ print "\t\t"$2 }' |cut -d ":" -f 2 | grep -v "^$")
ifaces=$(ip -br a | grep -v "lo\|docker\|veth\|br-\|^$" | awk '{print $1}')

LINE | tee -a "$mainlog"
echo -e "Starting Health Check Export: $(date +%Y%m%d-%H%M%0S)" | tee -a "$mainlog"
LINE | tee -a "$mainlog"

echo -e "" | tee -a "$mainlog"
echo -e "System Information:" | tee -a "$mainlog"
echo "$SYSTEMINFO" | tee -a "$mainlog"

echo -e "" | tee -a "$mainlog"
echo -e "OS Version:	$OS_VERSION" | tee -a "$mainlog"

echo -e "" | tee -a "$mainlog"
echo -e "Hostname:	$(hostname)" | tee -a "$mainlog"

echo -e "" | tee -a "$mainlog"
echo -e "IP Address:" | tee -a "$mainlog"
echo -e "$ips" | tee -a "$mainlog"

echo -e "" | tee -a "$mainlog"
UPTIME=$(uptime -s)
echo "System up since:	$UPTIME" | tee -a "$mainlog"

echo -e "" | tee -a "$mainlog"
LOADAVG=$(cat /proc/loadavg | awk '{print $3}')
echo -e "15 Minute Load Average:	$LOADAVG" | tee -a "$mainlog"

echo -e "" | tee -a "$mainlog"
HWTIME=$(hwclock --show)
echo "Hardware Clock Time: $HWTIME" | tee -a "$mainlog"

echo -e "" | tee -a "$mainlog"
SYSTIME=$(date +%Y-%m-%d_%H:%M:%S)
echo "System Clock Time: $SYSTIME" | tee -a "$mainlog"


if [ -n "$cc_installed" ]; then
	echo -e "" | tee -a "$mainlog"
	cc_installed_version=$(apt-cache policy silentdefense-cc | grep Install | sed -e 's/ Installed: *//')
	echo -e "CC installed. Version: $cc_installed_version" | tee -a "$mainlog"
fi

if [ -n "$sensor_installed" ]; then
	echo -e "" | tee -a "$mainlog"
	sensor_installed_version=$(apt-cache policy silentdefense-nids-ics | grep Install |sed -e 's/ Installed: *//')
	echo -e "Sensor installed. Version: $sensor_installed_version" | tee -a "$mainlog"
fi

echo -e "" | tee -a "$mainlog"
echo -e "Silentdefense Package Information" | tee -a "$mainlog"
column -t <<< $(dpkg-query --show | grep "silentdefense\|icsp\|nids") | sort | uniq | tee -a "$mainlog"
LINE | tee -a "$mainlog"

if [ -n "$cc_installed" ]; then
	PASSIVESENSORCOUNT='0'
	ACTIVESENSORCOUNT='0'
	PASSIVESENSORCOUNT=$($QUERYCMD "SELECT COUNT(*) from sensors where status!='999';" | cat | grep -A 1 "\-\-\-\-" | grep -v "\-\-\-\-" | awk '{print $1}')
	echo "Current Passive Sensor Count: $PASSIVESENSORCOUNT" | tee -a "$mainlog"

	ACTIVESENSORCOUNT=$($QUERYCMD "SELECT COUNT(*) from patrol_sensors where status!='999';" | cat | grep -A 1 "\-\-\-\-" | grep -v "\-\-\-\-" | awk '{print $1}')
	echo "Current Active Sensor Count:  $ACTIVESENSORCOUNT" | tee -a "$mainlog"

	TOTALSENSORS=$(($PASSIVESENSORCOUNT + $ACTIVESENSORCOUNT))
	echo "Total Sensors: $TOTALSENSORS"
fi

if [[ -f /etc/ntp.conf ]]; then
	LINE >> "$mainlog"
	echo -e "NTP Server(s) (ntp.conf)" | tee -a "$mainlog"
	grep "^server" /etc/ntp.conf >> "$mainlog"
fi

if [[ -r /usr/bin/timedatectl ]]; then
	LINE >> "$mainlog"
	echo -e "NTP Status" | tee -a "$mainlog"
	timedatectl status >> "$mainlog"
fi

if [[ -f /etc/systemd/timesyncd.conf ]]; then
	LINE >> "$mainlog"
	echo -e "NTP Configuration (from systemd)" | tee -a "$mainlog"
	grep -v "^$\|^#" /etc/systemd/timesyncd.conf >> "$mainlog"
fi

LINE >> "$mainlog"
echo -e "System Information" | tee -a "$mainlog"

LINE >> "$mainlog"
echo -e "Processor Information" | tee -a "$mainlog"
threads="$(lscpu | grep "^CPU(s):" | awk '{print $2}')"
echo -e "CPU Threads: $threads" | tee -a "$mainlog"

LINE >> "$mainlog"
echo -e "System Memory Information" | tee -a "$mainlog"
ram=$(lsmem | grep "^Total online memory:" | awk '{print $NF}')
echo -e "System Memory: $ram" | tee -a "$mainlog"

LINE >> "$mainlog"
echo -e "Swap & Memory usage Information" | tee -a "$mainlog"
free -m >> "$mainlog"

LINE >> "$mainlog"
echo -e "System Disk Information" | tee -a "$mainlog"
# echo -e "$hw" |grep -E 'disk' |sed -n -e 's/^.*\(disk \)/\1/p' >> "$mainlog"
lsblk --nodeps  | grep -v loop >> "$mainlog"

LINE >> "$mainlog"
echo -e "Filesystem Table Information (fstab)" | tee -a "$mainlog"
cat /etc/fstab >> "$mainlog"

LINE >> "$mainlog"
echo -e "Filesystem Information" | tee -a "$mainlog"
df -m >> "$mainlog"

LINE >> "$mainlog"
echo -e "Physical Block Information (All attached disks)" | tee -a "$mainlog"
lsblk -a >> "$mainlog"

if [[ -r /usr/sbin/pvdisplay ]]; then
	LINE >> "$mainlog"
	echo -e "Physical Volume Information" | tee -a "$mainlog"
	pvdisplay >> "$mainlog"
fi

if [[ -r /usr/sbin/vgdisplay ]]; then
	LINE >> "$mainlog"
	echo -e "Volume Group Information" | tee -a "$mainlog"
	vgdisplay >> "$mainlog"
fi

if [[ -r /usr/sbin/lvdisplay ]]; then
	LINE >> "$mainlog"
	echo -e "Logical Volume Information" | tee -a "$mainlog"
	lvdisplay >> "$mainlog"
fi

###########################################################################
# Show spinner while waiting for du command to finish
#LINE >> "$mainlog"
#echo -e "Largest (25) Files & Directories in / (This will take some time. Please wait.)"
#echo -e "Largest (25) Files & Directories in /" >> "$mainlog"
#du -aBm /* --exclude=/proc --exclude=/sys | sort -hr | head -n 25 2>/dev/null >> "$mainlog" &
#SPINNER

###########################################################################
# networking log:
netlog=$(padded $i "Network.log"); ((i++))
LINE >> "$mainlog"
echo -e "Network Information: $netlog" | tee -a "$mainlog"
if [[ -f /usr/sbin/netplan ]]; then
	LINE >> "$netlog"
	echo -e "Netplan Configuration" | tee -a "$netlog"
	netplan get all >> "$netlog"
	LINE >> "$netlog"
	echo -e "Netplan Brief Information" | tee -a "$netlog"
	ip -br a >> "$netlog"
fi

if [[ -r /etc/network/interfaces ]]; then
	LINE >> "$netlog"
	echo -e "Network Interfaces Configuration" | tee -a "$netlog"
	cat /etc/network/interfaces >> "netlog"
fi

echo -e "Primary NIC configuration" | tee -a "$netlog"
LINE >> "$netlog"
for interface in $(echo "$ifaces"); do
	echo "Interface: $interface" | tee -a "$netlog"
	ethtool "$interface" >> "$netlog"
done

LINE >> "$netlog"
echo -e "Full ifconfig Details" | tee -a "$netlog"
echo -e "$ifcon" >> "$netlog"
if [[ -f /etc/resolv.conf ]]; then
	LINE >> "$netlog"
	echo -e "DNS Configuration (resolv.conf)" | tee -a "$netlog"
	cat /etc/resolv.conf >> "$netlog"
fi

LINE >> "$netlog"
if [[ -f /usr/bin/resolvectl ]]; then
	LINE >> "$netlog"
	echo -e "ResolveCTL Status" | tee -a "$netlog"
	resolvectl status >> "$netlog"
fi

LINE >> "$netlog"
echo -e "Network Statistical Data (netstat)" | tee -a "$netlog"
netstat -ntu >> "$netlog"

###########################################################################
# firewall rules (iptables & ufw):
fwlog=$(padded $i "Firewall.log"); ((i++))
LINE >> "$mainlog"
echo -e "Firewall Rules & Information: $fwlog" | tee -a "$mainlog"

if [[ -f "/usr/sbin/iptables" ]]; then
	LINE >> "$fwlog"
	echo -e "IPTables Firewall Rules" | tee -a "$fwlog"
	iptables -L  >> "$fwlog"
	LINE >> "$fwlog"
	echo -e "Verbose IPTables Firewall Status" | tee -a "$fwlog"
	iptables -L -n -v >> "$fwlog"
fi

if [[ -f "/usr/sbin/ufw" ]]; then
	LINE >> "$fwlog"
	echo -e "Berkeley Packet Filter Information" | tee -a "$fwlog"
	ufw status verbose >> "$fwlog"
fi

###########################################################################
# packages
LINE >> "$mainlog"
packagelog=$(padded $i "Packages.log"); ((i++))
echo -e "All Installed Packages Information: $packagelog" | tee -a "$mainlog"
column -t <<< $(sudo dpkg-query --show) >> "$packagelog"

# SupervisorCTL:
if [[ -f /usr/bin/supervisorctl ]]; then
	LINE >> "$mainlog"
	echo -e "SupervisorCTL Service Information" | tee -a "$mainlog"
	supervisorctl status >> "$mainlog"
fi

if [[ -f /var/log/supervisor/supervisord.log ]]; then
	LINE >> "$mainlog"
	superlog=$(padded $i "SupervisorCTL"); ((i++))
	echo -e "SupervisorCTL Service Logs: $superlog" | tee -a "$mainlog"
	cp -a /var/log/supervisor/ "$superlog" > /dev/null 2>&1
fi

###########################################################################
# SystemCTL:
if [[ -f /usr/bin/systemctl ]]; then
	sysctllog=$(padded $i "SystemCTL.log"); ((i++))
	LINE >> "$mainlog"
	echo -e "systemd Failed Services" | tee -a "$mainlog"
	systemctl list-units --state failed >> "$mainlog"
	echo -e "System Service Information: $sysctllog" | tee -a "$mainlog"
	systemctl status >> "$sysctllog"
fi

###########################################################################
# Process log:
pslog=$(padded $i "PS.log"); ((i++))
LINE >> "$mainlog"
echo -e "System Process Information: $pslog" | tee -a "$mainlog"
ps -aux >> "$pslog"

###########################################################################
# Open Files log:
#lsoflog=$(padded $i "Open_Files_Pending_Deletion.log"); ((i++))
#LINE >> "$mainlog"
#echo -e "Open Files Pending Deletion: $lsoflog" | tee -a "$mainlog"
#lsof | grep "(deleted)" > "$lsoflog" 2>&1 & SPINNER

###########################################################################
# Docker containers:
if [[ -f /usr/bin/docker ]]; then
	LINE >> "$mainlog"
	echo -e "Docker Information" | tee -a "$mainlog"
	docker ps >> "$mainlog"
	dockerlogs=$(padded $i "Docker_Logs"); ((i++))
	mkdir -p "$dockerlogs"
	echo "Docker Containers:" | tee -a "$mainlog"
	for dockercontainer in $(sudo docker ps | tail +2 | awk '{print $NF}')
		do
			echo "$dockercontainer Log: $dockerlogs/$dockercontainer.log" | tee -a "$mainlog"
			docker logs "$dockercontainer" > "$dockerlogs/$dockercontainer.log" 2>&1
		done
fi

###########################################################################
# Syslog:
if [[ -f /var/log/syslog ]]; then
	LINE >> "$mainlog"
	systemlogs=$(padded $i "System_Logs"); ((i++))
	mkdir -p "$systemlogs"
	echo -e "System Logs (syslog): $systemlogs" | tee -a "$mainlog"
	cp /var/log/syslog* "$systemlogs" > /dev/null 2>&1
fi

###########################################################################
# Kernel log:
if [[ -f /var/log/kern.log ]]; then
	LINE >> "$mainlog"
	kernellogs=$(padded $i "Kernel_Logs"); ((i++))
	mkdir -p "$kernellogs"
	echo -e "Kernel Logs (kern.log): $kernellogs" | tee -a "$mainlog"
	cp /var/log/kern.log* "$kernellogs" > /dev/null 2>&1
fi

###########################################################################
# cron tasks
cronconf=$(padded $i "Cron_Configs.conf"); ((i++))
LINE >> "$mainlog"
echo -e "Cron Jobs: $cronconf" | tee -a "$mainlog"
for cronscript in $(find /etc/cron* -type f); do
	BREAK >> "$cronconf"
	echo -e "# $cronscript" >> "$cronconf"
	cat "$cronscript" >> "$cronconf"
	echo -e "" >> "$cronconf"
done
for cronscript in $(find /var/spool/cron/crontabs/ -type f); do
	BREAK >> "$cronconf"
	echo -e "# $cronscript" >> "$cronconf"
	cat "$cronscript" >> "$cronconf"
	echo -e "" >> "$cronconf"
done


###########################################################################
# command center logs:
if [ -n "$cc_installed" ]; then
	LINE >> "$mainlog"
	echo -e "Command Center specific Logs" | tee -a "$mainlog"
	PASSIVESENSORCOUNT='0'
	ACTIVESENSORCOUNT='0'
	PASSIVESENSORCOUNT=$($QUERYCMD "SELECT COUNT(*) from sensors where status!='999';" | cat | grep -A 1 "\-\-\-\-" | grep -v "\-\-\-\-" | awk '{print $1}')
	echo -e "Current Passive Sensor Count: $PASSIVESENSORCOUNT" | tee -a "$mainlog"

	ACTIVESENSORCOUNT=$($QUERYCMD "SELECT COUNT(*) from patrol_sensors where status!='999';" | cat | grep -A 1 "\-\-\-\-" | grep -v "\-\-\-\-" | awk '{print $1}')
	echo -e "Current Active Sensor Count:  $ACTIVESENSORCOUNT" | tee -a "$mainlog"

	TOTALSENSORS=$(($PASSIVESENSORCOUNT + $ACTIVESENSORCOUNT))
	echo -e "Total Sensors: $TOTALSENSORS" | tee -a "$mainlog"
	echo -e "" >> "$mainlog"
	
	settingsdir=$(padded $i "System_Settings"); ((i++))
	mkdir -p "$settingsdir"
	if [[ -d /opt/sdconsole/conf ]]; then
		echo -e "eyeInspect Application Settings: $settingsdir/sdconsole_settings" | tee -a "$mainlog"
		cp -a /opt/sdconsole/conf/ "$settingsdir/sdconsole_settings" | tee -a "$mainlog"
		echo -e "" >> "$mainlog"
	fi
	if [[ -d /opt/kafka/config ]]; then
		echo -e "Kafka Application Settings: $settingsdir/kafka_settings" | tee -a "$mainlog"
		cp -a /opt/kafka/config "$settingsdir/kafka_settings" | tee -a "$mainlog"
		echo -e "" >> "$mainlog"
	fi
	if [[ -d /opt/druid/conf/ ]]; then
		echo -e "Druid Application Settings: $settingsdir/druid_settings" | tee -a "$mainlog"
		cp -a /opt/druid/conf/ "$settingsdir/druid_settings" | tee -a "$mainlog"
		echo -e "" >> "$mainlog"
	fi
	
	# PostgreSQL Password Check:
	POSTGRES_CC_CONF="/opt/sdconsole/tomcat/webapps/ROOT/META-INF/context.xml"
	LOCALPGPASSWORD=$(grep "password=\"" "$POSTGRES_CC_CONF" | sed 2>/dev/null "s/.*password=\"//" | sed 2>/dev/null "s/\".*//")
	pgpwstatus=$(PGPASSWORD="$LOCALPGPASSWORD" psql -U sduser -h localhost -d silentdefense -c "SELECT id from sensors where null;" | grep '(0 rows)' | sed 's/(0\ rows)/GOOD/g')
	echo -e "Postgres Password Status: $pgpwstatus" | tee -a "$mainlog"

	cclicense=$(padded $i "cc.license"); ((i++))
	echo -e "Command Center License: $cclicense" | tee -a "$mainlog"
	sudo -u postgres psql -qAt -P pager=off -d silentdefense -c "select value from system_settings where key='command_center_license'" | base64 -d > "$cclicense"
	expiration=$(grep expiryDate $cclicense | sed 's/expiryDate=//g')
	expiration=$(grep expiryDate EIHC-Logs-cc55test-20241201/13_cc55test_cc.license | sed 's/expiryDate=//g')
	converted=$(date -d "$expiration" +"%s")
	echo "Converted date: $converted" | tee -a "$mainlog" 
	current_date=$(date +"%s")
	echo "Current date: $current_date" | tee -a "$mainlog"
	if [ $current_date -lt $converted ]; then
		licensediff=$(( $converted - $current_date )) 
		validdays=$(( $licensediff / 86400 ))
		echo "License valid for $validdays days"; 
	elif [ $current_date -eq $converted ]; then 
		echo 'Expiring today'; 
	elif [ $current_date -gt $converted ]; then 
		echo 'License expired'; 
	fi
	echo "License expiration: $expiration"
	# Placeholder
	
	passivesensorlog=$(padded $i "Passive_Sensors_Details.csv"); ((i++))
	echo -e "Current Passive Sensor Export: $passivesensorlog" | tee -a "$mainlog"
	$QUERYCMD "copy (select * from sensors order by name) to '$passivesensorlog' with CSV DELIMITER ',' HEADER;"

	activesensorlog=$(padded $i "Active_Sensors_Details.csv"); ((i++))
	echo -e "Current Active Sensor Export: $activesensorlog" | tee -a "$mainlog"
	$QUERYCMD "copy (SELECT * from patrol_sensors order by name) to '$activesensorlog' with CSV DELIMITER ',' HEADER;"

	echo -e "Alert Details Grouped by Event Type ID" | tee -a "$mainlog"
	$QUERYCMD "select event_type_id, count (event_type_id) from alert_details group by event_type_id order by count desc;" | grep -v " rows)" >> "$mainlog"

	echo -e "Database Health Information" | tee -a "$mainlog"
	$QUERYCMD "select  table_name,pg_size_pretty(pg_relation_size(quote_ident(table_name))),pg_relation_size(quote_ident(table_name)) from information_schema.tables where table_schema = 'public' order by pg_relation_size desc;" | grep -v " rows)" >> "$mainlog"

	echo -e "SD Scripts (In use)" | tee -a "$mainlog"
	$QUERYCMD "select distinct module_name from modules where module_name is not null and is_deleted='f' order by module_name desc;" | grep -v " rows)" >> "$mainlog"

	echo -e "Sensor Disconnections (This may take some time. Please wait.)"
	disconlog=$(padded $i "Sensor_Disconnects.csv"); ((i++))

	echo -e "Sensor Disconnections: $disconlog" | tee -a "$mainlog"
	$QUERYCMD "
	copy(with disc_per_sens_per_day as (
	select
		s.name as sensor_name,
		timestamp::date as date,
		count(*) as disconnections_count
	from
		sensor_logs sl inner join sensors s on sl.sensor_id = s.id
	where
		msg ilike '%disconnect%' and s.status = 4
	group by
		s.name, timestamp::date
	order by
		timestamp::date desc, s.name
	)
	select
	  sensor_name,
	  date,
	  disconnections_count,
	  sum(disconnections_count) over (partition by sensor_name order by sensor_name) disconnections_total_per_sensor
	from
	  disc_per_sens_per_day) to '$disconlog' with CSV DELIMITER ',' HEADER;" & SPINNER

	if [[ $(find /etc/postgresql/11/main/postgresql.conf) ]]; then
		dbconf=$(padded $i "Postgresql.conf"); ((i++))
		echo -e "Postgres Configuration: $dbconf" | tee -a "$mainlog"
		cp /etc/postgresql/11/main/postgresql.conf "$dbconf" > /dev/null 2>&1
	fi

	if [[ -d /var/log/postgresql/ ]]; then
		postgresqllogdir=$(padded $i "PostgreSQL_Logs"); ((i++))
		echo -e "PostgreSQL Logs: $postgresqllogdir" | tee -a "$mainlog"
		cp -a /var/log/postgresql/ "$postgresqllogdir"
		postgresqlactivitylog="$postgresqllogdir/PostgreSQL_Activity.log"
		echo -e "PostgreSQL Activity Log: $postgresqlactivitylog" | tee -a "$mainlog"
		sudo -u postgres psql -d silentdefense -c "SELECT pid, age(clock_timestamp(), query_start), usename, query FROM pg_stat_activity WHERE query != '<IDLE>' AND query NOT ILIKE '%pg_stat_activity%' ORDER BY query_start desc;" > "$postgresqlactivitylog" & SPINNER
		echo -e "Getting PostgreSQL Database structures:"
		postgresstructuredir="$postgresqllogdir/PostgreSQL_Structure"
		mkdir -p "$postgresstructuredir"
		echo -e "SilentDefense database structure: $postgresstructuredir/silentdefense_database.dump"
		sudo -u postgres pg_dump -s silentdefense > "$postgresstructuredir/silentdefense_database.dump"
		echo -e "Druid database structure: $postgresstructuredir/druid_database.dump"
		sudo -u postgres pg_dump -s druid > "$postgresstructuredir/druid_database.dump"
	fi

	if [[ -d /opt/sdconsole/tomcat/logs ]]; then
		tomcatlogdir=$(padded $i "Tomcat_Logs"); ((i++))
		echo -e "Tomcat Catalina Logs: $tomcatlogdir" | tee -a "$mainlog"
		cp -a /opt/sdconsole/tomcat/logs "$tomcatlogdir"
	fi
	# Kafka Log(s):
	LINE >> "$mainlog"
	if [[ -d /var/log/kafka ]]; then
		kafkalogs=$(padded $i "Kafka_Logs"); ((i++))
		echo -e "Kafka Log(s): $kafkalogs" | tee -a "$mainlog"
		cp -a /var/log/kafka $kafkalogs
	fi

	# Druid Logs:
	if [[ -d /opt/druid ]]; then
		druidlogs=$(padded $i "Druid_Logs"); ((i++))
		echo -e "Druid Logs: $druidlogs" | tee -a "$mainlog"
		cp -a /var/log/druid "$druidlogs"
		druidlog="$druidlogs/Druid_Data.log"
		if [[ -f  /var/log/druid-dynamic-historical-segment-size.log ]]; then
			cp -a /var/log/druid-dynamic-historical-segment-size.log "$druidlogs"
		fi
		echo -e "Druid Data: $druidlog" | tee -a "$mainlog"
		# SETUP LOGGING TO SINGLE DIRECTORY
		# Druid data gathering:
		echo -e "Druid config data (API call)" > "$druidlog"
		curl -s -X 'GET' localhost:8081/druid/coordinator/v1/config | sed 's/[{}]//g' | sed 's/,/\n/g' >> "$druidlog"
		if [[ $(find /opt/druid/conf/coordinator/runtime.properties 2> /dev/null) ]]; then
			LINE >> "$druidlog"
			echo -e "Druid Runtime Properties: " >> "$druidlog"
			cat /opt/druid/conf/coordinator/runtime.properties >> "$druidlog"
			RETENTION=$(grep druid.coordinator.kill.durationToRetain /opt/druid/conf/coordinator/runtime.properties | sed 's/^.*=//g' | sed 's/[D,P]//g')
			# Past Retention:
			LINE  >> "$mainlog"
			echo -e "Files older than current retention period: " | tee -a "$mainlog"
			# Find Number of files older than retention period in /opt/druid-data/events
			echo -e "Druid Retention Period: $RETENTION" | tee -a "$mainlog"
			DRUIDPATHS="/opt/druid-data/events /opt/druid-data/flow-info /tmp/druid/indexCache/flow-info /tmp/druid/indexCache/events /opt/druid-data/tasklogs/ /opt/druid-data/taskLogs/"
			for DRUIDPATH in $DRUIDPATHS;
			do
				if [[ -d $DRUIDPATH ]]; then
					DRUIDCOUNT=$(find $DRUIDPATH -type f -mtime $RETENTION | wc -l)
					echo -e "$DRUIDPATH: $DRUIDCOUNT" | tee -a "$mainlog"
				else
					echo "'$DRUIDPATH' doesn't appear to exist"
				fi
			done
			LINE >> "$mainlog"
		fi
		
		for druiddatadir in $(ls /opt/druid-data/)
			do
				echo "Druid Data Directory: $druiddatadir" | tee -a "$mainlog"
			done

		# Find oldest 10 files in /opt/druid-data/events
		if [[ -d /opt/druid-data/events ]]; then
			LINE >> "$druidlog"
			echo -e "Oldest 10 files in /opt/druid-data/events:" >>"$druidlog"
			find /opt/druid-data/events -type f -exec du -sh {} \; | sort | head -n 10 | sed 's/\t/\t\t/g' >> "$druidlog"
		fi
		
		# Find oldest 10 files in /opt/druid-data/flow-info
		if [[ -d /opt/druid-data/flow-info ]]; then
			LINE >> "$druidlog"
			echo -e "Oldest 10 files in /opt/druid-data/flow-info:" >>"$druidlog"
			find /opt/druid-data/flow-info -type f -exec du -sh {} \; | sort | head -n 10 | sed 's/\t/\t\t/g' >>"$druidlog"
		fi
		
		# Find oldest 10 files in /tmp/druid/indexCache/events
		if [[ -d /tmp/druid/indexCache/events ]]; then
			LINE >> "$druidlog"
			echo -e "Oldest 10 files in /tmp/druid/indexCache/events" >>"$druidlog"
			find /tmp/druid/indexCache/events -type f -exec du -sh {} \; | sort | head -n 10 | sed 's/\t/\t\t/g' >>"$druidlog"
		fi
		
		# Find oldest 10 files in /tmp/druid/indexCache/flow-info
		if [[ -d /tmp/druid/indexCache/flow-info ]]; then
			LINE >> "$druidlog"
			echo -e "Oldest 10 files in /tmp/druid/indexCache/flow-info" >>"$druidlog"
			find /tmp/druid/indexCache/flow-info -type f -exec du -sh {} \; | sort | head -n 10 | sed 's/\t/\t\t/g' >>"$druidlog"
		fi
	
		# Find oldest 10 files in /opt/druid-data/tasklogs/
		if [[ -d /opt/druid-data/tasklogs/ ]]; then
			LINE >> "$druidlog"
			echo -e "Oldest 10 files in /opt/druid-data/tasklogs/" >>"$druidlog"
			find /opt/druid-data/tasklogs/ -type f -printf '%T+\t%p\n' | sort | head -n 10 >>"$druidlog"
		fi
		
		# Find oldest 10 files in /opt/druid-data/taskLogs/
		if [[ -d /opt/druid-data/taskLogs/ ]]; then
			LINE >> "$druidlog"
			echo -e "Oldest 10 files in /opt/druid-data/taskLogs/:" >>"$druidlog"
			find /opt/druid-data/taskLogs/ -type f -printf '%T+\t%p\n' | sort | head -n 10 >>"$druidlog"
		fi
	fi
	##############################################################################################
	# Sensor Health via python script
	if [ $SENSORHEALTH == true ]; then
		if [[ -f $tmpsensorhealth ]]; then
			sensorhealthlog=$(padded $i "Sensors_Health.csv"); ((i++))
			sensormodulelog=$(padded $i "Sensors_Modules.csv"); ((i++))
			LINE >> "$mainlog"
			echo -e "Sensor Health: $sensorhealthlog" | tee -a "$mainlog"
			echo -e "(This may take some time. Please wait.)"
			python3 $tmpsensorhealth -p $USERPASS -c $CCADDRESS -u $USERNAME -o $sensorhealthlog -m $sensormodulelog &
			SPINNER
			echo "Removing sensor health script"
			rm -rf $tmpsensorhealth
		else
			echo -e "Sensor Health Script Unavailable" | tee -a "$mainlog"
		fi
	fi
	##############################################################################################
	KPICHECK() {
		LINE >> "$mainlog"
		# KPI Script:
		kpilog=$(padded $i "KPI.log"); ((i++))
		echo -e "KPI Log: $kpilog"
		set -e

		START_TIME=$(date --date="$(date +'%Y-%m-%d') - 1 year")
		END_TIME=$(date --date="$(date +'%Y-%m-%d')")
		# Format: YYYY-MM-DDTHH:mm:ssZ (seems to need to be in Zulu/UTC)
		DRUID_START_TIME=$(TZ=UTC date -d "${START_TIME}" '+%Y-%m-%dT%H:%M:%SZ')
		DRUID_END_TIME=$(TZ=UTC date -d "${END_TIME}" '+%Y-%m-%dT%H:%M:%SZ')

		export PGPASSWORD
		printf "All hosts right now: " >> "$kpilog"

		HOST_NUMBER=$($QUERYCMD "select count(*) from hosts" | grep -v " row)\|----\|count")
		echo -e $HOST_NUMBER >> "$kpilog"

		# Get a count of unknown hosts.
		printf "HOSTS WITH UNKNOWN ROLES right now: " >> "$kpilog"
		UNKNOWN_HOST_NUMBER=$($QUERYCMD "select count(*) as unknown_roles from hosts where main_role = '' or main_role='unknown'" | grep -v " row)\|----\|count")
		echo -e $UNKNOWN_HOST_NUMBER >> "$kpilog"

		# Get a count of unknown hosts, divide by total hosts, multiply by 100 to
		# get percentage, round to 2 decimal places.
		printf "HOSTS WITH UNKNOWN ROLES (percentage) right now: " >> "$kpilog"
		UNKNOWN_HOST_NUMBER_PERC=$($QUERYCMD "select round (100 * count(*)::DECIMAL / (select count(*) from hosts), 2) from hosts where main_role = '' or main_role='unknown'" | grep -v " row)\|----\|count")
		echo -e $UNKNOWN_HOST_NUMBER_PERC >> "$kpilog"

		# KPI - Indicators for the selected time window

		# Get a count of hosts first seen in the reporting period
		printf "HOSTS first seen in the reporting period: " >> "$kpilog"
		NEW_HOSTS=$($QUERYCMD "select sum(case when first_seen between TIMESTAMPTZ '${START_TIME}' and TIMESTAMPTZ '${END_TIME}' then 1 else 0 end) from hosts" | grep -v " row)\|----\|count")
		echo -e $NEW_HOSTS >> "$kpilog"


		# Get a count of hosts first seen this reporting period with
		# a main_role not set, divide by total hosts, multiply by 100 to get percentage,
		# round to 2 decimal places.
		printf "HOSTS first seen this reporting period WITH UNKNOWN ROLES: " >> "$kpilog"
		NEW_HOSTS_PERC=$($QUERYCMD "select round (100 * count(*)::DECIMAL / (select count(*) from hosts), 2) from hosts where main_role = ''  or main_role='unknown' and first_seen between TIMESTAMPTZ '${START_TIME}' and TIMESTAMPTZ '${END_TIME}'" | grep -v " row)\|----\|count")
		echo -e $NEW_HOSTS_PERC >> "$kpilog"

		# Get NAKO traffic for the reporting period using curl to the local Druid broker
		# Note that the return value may be in scientific notation. To convert to kb, divide by 1024
		# Use the START_TIME and END_TIME variables which are local time zone for simplicity
		# Note that you need to end the single quoted section of the curl command in order to interpret the variales
		printf "" >> "$kpilog"
		printf %s "UNKNOWN Traffic in bytes for time: " $DRUID_START_TIME " to " $DRUID_END_TIME " : " >> "$kpilog"

		UNKNOWN_TRAFFIC_JSON=$(curl -s -X 'POST' -H 'Content-Type:application/json' http://localhost:8082/druid/v2/?pretty -d '{"queryType":"groupBy","dataSource":{"type":"table","name":"flow-info"},"intervals":{"type":"LegacySegmentSpec","intervals":["'${DRUID_START_TIME}'/'${DRUID_END_TIME}'"]},"virtualColumns":[],"filter":{"type":"and","fields":[{"type":"and","fields":[{"type":"selector","dimension":"l7_proto","value":"NOTAKNOWNONE","extractionFn":{"type":"upper","localeString":null}}]},{"type":"not","field":{"type":"selector","dimension":"l2_proto","value":null,"extractionFn":null}},{"type":"not","field":{"type":"selector","dimension":"l2_proto","value":"null","extractionFn":null}}]},"granularity":{"type":"all"},"dimensions":[{"type":"default","dimension":"l2_proto","outputName":"l2_proto","outputType":"STRING"}],"aggregations":[{"type":"doubleSum","name":"t_bytes","fieldName":"t_bytes","expression":null}],"postAggregations":[],"having":null,"limitSpec":{"type":"NoopLimitSpec"}}')
		EMPTY='[ ]'

		if [[ "$UNKNOWN_TRAFFIC_JSON" == *"$EMPTY"* ]]; then
			UNKNOWN_TRAFFIC=0
		else
			UNKNOWN_TRAFFIC=$(echo $UNKNOWN_TRAFFIC_JSON | sed "s/.*t_bytes\" : //" | sed "s/,.*//")
			UNKNOWN_TRAFFIC=$(printf '%.0f\n' $UNKNOWN_TRAFFIC)
		fi
		echo $UNKNOWN_TRAFFIC >> "$kpilog"

		# Get KNOWN (i.e. not NAKO) traffic for the reporting period using curl to the local Druid broker
		# Aggregate to the L3 protocol (ETHERNET) to get a single aggregate value.
		# Note that the return value may be in scientific notation. To convert to kb, divide by 1024
		# Use the START_TIME and END_TIME variables which are local time zone for simplicity
		# Note that you need to end the single quoted section of the curl command in order to interpret the variales
		printf "" >> "$kpilog"
		printf %s "KNOWN traffic in bytes for time: " $DRUID_START_TIME " to " $DRUID_END_TIME " : " >> "$kpilog"

		KNOWN_TRAFFIC_JSON=$(curl -s -X 'POST' -H 'Content-Type:application/json' http://localhost:8082/druid/v2/?pretty -d '{"queryType":"groupBy","dataSource":{"type":"table","name":"flow-info"},"intervals":{"type":"LegacySegmentSpec","intervals":["'${DRUID_START_TIME}'/'${DRUID_END_TIME}'"]},"virtualColumns":[],"filter":{"type":"and","fields":[{"type":"and","fields":[{"type":"not","field":{"type":"selector","dimension":"l7_proto","value":"NOTAKNOWNONE","extractionFn":{"type":"upper","localeString":null}}}]},{"type":"not","field":{"type":"selector","dimension":"l2_proto","value":null,"extractionFn":null}},{"type":"not","field":{"type":"selector","dimension":"l2_proto","value":"null","extractionFn":null}}]},"granularity":{"type":"all"},"dimensions":[{"type":"default","dimension":"l2_proto","outputName":"l2_proto","outputType":"STRING"}],"aggregations":[{"type":"doubleSum","name":"t_bytes","fieldName":"t_bytes","expression":null}],"postAggregations":[],"having":null,"limitSpec":{"type":"NoopLimitSpec"}}')
		EMPTY='[ ]'

		if [[ "$KNOWN_TRAFFIC_JSON" == *"$EMPTY"* ]]; then
			KNOWN_TRAFFIC=1
		else
			KNOWN_TRAFFIC=$(echo $KNOWN_TRAFFIC_JSON | sed "s/.*t_bytes\" : //" | sed "s/,.*//")
			KNOWN_TRAFFIC=$(printf '%.0f\n' $KNOWN_TRAFFIC)
		fi
		echo $KNOWN_TRAFFIC >> "$kpilog"

		UNKNOWN_TRAFFIC_PERCENTAGE=$(awk "BEGIN {printf \"%.2f\n\", 100 * $UNKNOWN_TRAFFIC/($UNKNOWN_TRAFFIC+$KNOWN_TRAFFIC)}" | grep -v " row)\|----\|count")

		printf "" >> "$kpilog"
		printf %s "UNKNOWN traffic percentage for time: " $DRUID_START_TIME " to " $DRUID_END_TIME " : " >> "$kpilog"
		echo $UNKNOWN_TRAFFIC_PERCENTAGE >> "$kpilog"

		# Get alerts for reporting period
		# use alerts table and timestamp fields.
		printf "ALERTS for the reporting period: " >> "$kpilog"
		ALERT_NUMBER=$($QUERYCMD "select count(*) from alert_details a where a.timestamp between TIMESTAMPTZ '${START_TIME}' and TIMESTAMPTZ '${END_TIME}'" | grep -v " row)\|----\|count")
		echo -e $ALERT_NUMBER >> "$kpilog"

		# psql -P pager=off -h localhost -d $DATABASE -p $DB_PORT -U $DB_USER -q -v ON_ERROR_STOP=1 -c "\
		# select s.name as sensor, count(a.severity) as alerts \
		# 	from sensors s, alerts a \
		# 	where a.sensor_id=s.id and \
		# 		a.timestamp between TIMESTAMPTZ '${START_TIME}' and TIMESTAMPTZ '${END_TIME}' \
		# 	group by s.name \
		# 	order by s.name;" >> "$kpilog"

		# Get critical alerts for the reporting period
		# use alerts table severity, and timestamp fields.
		# Severity 1 = info, 2 = low, 3 = medium, 4 = high, 5 = critical
		printf "Critical ALERTS for the reporting period: " >> "$kpilog"
		CRITICAL_ALERT_NUMBER=$($QUERYCMD "select count(*) from alert_details a where a.timestamp between TIMESTAMPTZ '${START_TIME}' and TIMESTAMPTZ '${END_TIME}' and a.severity = 5" | grep -v " row)\|----\|count")
		echo -e $CRITICAL_ALERT_NUMBER >> "$kpilog"

		# Get number of open cases. For the status field, 0=open, 1=closed false alert, 2=closed solved, 3=closed not relevant,
		# 4=closed trimmed, and 5=closed unknown.
		printf "Open cases right now: " >> "$kpilog"
		OPEN_CASES_NUMBER=$($QUERYCMD "select count(*) from cases c where c.status=0" | grep -v " row)\|----\|count")
		echo -e $OPEN_CASES_NUMBER >> "$kpilog"

		# Get critical CC health alerts for the reporting period.
		printf "Command Center HEALTH ALERTS for the reporting period: " >> "$kpilog"
		CRITICAL_CC_HEALTH_ALERT_NUMBER=$($QUERYCMD "select count(*) from health_status_logs l where l.device_id IS NULL and l.timestamp between TIMESTAMPTZ '${START_TIME}' and TIMESTAMPTZ '${END_TIME}' and l.current_hs like '%CRITICAL%'" | grep -v " row)\|----\|count")
		echo -e $CRITICAL_CC_HEALTH_ALERT_NUMBER >> "$kpilog"

		# Get critical sensor health alerts for the reporting period.
		printf "Sensor HEALTH ALERTS for the reporting period: " >> "$kpilog"
		CRITICAL_SENSOR_HEALTH_ALERT_NUMBER=$($QUERYCMD "select count(*) from health_status_logs l where l.device_id IS NOT NULL and l.timestamp between TIMESTAMPTZ '${START_TIME}' and TIMESTAMPTZ '${END_TIME}' and l.current_hs ilike '%CRITICAL%'" | grep -v " row)\|----\|count")
		echo -e $CRITICAL_SENSOR_HEALTH_ALERT_NUMBER >> "$kpilog"
	}
	# Try running the KPI Check, but continue if it errors:
	KPICHECK || true
fi

###########################################################################
# sensor logs:
# current hs, previous hs, monitor-nids, nids
if [ -n "$sensor_installed" ]; then
	LINE >> "$mainlog"
	echo -e "Sensor specific Logs" | tee -a "$mainlog"
	if [[ $(find /opt/nids/logs/current.log 2> /dev/null) ]]; then
		currnidslog=$(padded $i "Current_NIDS.log"); ((i++))
		echo -e "Current NIDS Log: $currnidslog" | tee -a "$mainlog"
		cp /opt/nids/logs/current.log "$currnidslog" 2>/dev/null
	fi
	if [[ $(find /opt/nids/logs/previous.log 2> /dev/null) ]]; then
		prevnidslog=$(padded $i "Previous_NIDS.log"); ((i++))
		LINE >> "$mainlog"
		echo -e "Previous NIDS Log: $prevnidslog" | tee -a "$mainlog"
		cp /opt/nids/logs/previous.log "$prevnidslog" 2>/dev/null
	fi
	if [[ $(find /var/log/supervisor/monitor-nids-stdout*.log 2> /dev/null) ]]; then
		monnidsoutlog=$(padded $i "Monitor_NIDS_stdout.log"); ((i++))
		LINE >> "$mainlog"
		echo -e "Monitor NIDS Log: $monnidsoutlog" | tee -a "$mainlog"
		cp /var/log/supervisor/monitor-nids-stdout*.log "$monnidsoutlog" 2>/dev/null
	fi
	if [[ $(find /var/log/supervisor/monitor-nids-stderr*.log 2> /dev/null) ]]; then
		monnidserrlog=$(padded $i "Monitor_NIDS_stderr.log"); ((i++))
		LINE >> "$mainlog"
		echo -e "Monitor NIDS Error Log: $monnidserrlog" | tee -a "$mainlog"
		cp /var/log/supervisor/monitor-nids-stderr*.log "$monnidserrlog" 2>/dev/null
	fi
	if [[ $(find /var/log/supervisor/nids-stdout*.log 2> /dev/null) ]]; then
		nidsoutlog=$(padded $i "NIDS_stdout.log"); ((i++))
		LINE >> "$mainlog"
		echo -e "NIDS Log: $nidsoutlog" | tee -a "$mainlog"
		cp /var/log/supervisor/nids-stdout*.log "$nidsoutlog" 2>/dev/null
	fi
	if [[ $(find /var/log/supervisor/nids-stderr*.log 2> /dev/null) ]]; then
		nidserrlog=$(padded $i "NIDS_stderr.log"); ((i++))
		LINE >> "$mainlog"
		echo -e "NIDS Error Log: $nidserrlog" | tee -a "$mainlog"
		cp /var/log/supervisor/nids-stderr*.log "$nidserrlog" 2>/dev/null
	fi
	if [[ $(find /opt/nids-docker/state/conf/nids.conf 2> /dev/null) ]]; then
		nidsconf=$(padded $i "NIDS.conf"); ((i++))
		LINE >> "$mainlog"
		echo -e "NIDS Configuration: $nidsconf" | tee -a "$mainlog"
		cp /opt/nids-docker/state/conf/nids.conf "$nidsconf" 2>/dev/null
	fi
fi

###########################################################################

LINE | tee -a "$mainlog"
echo -e "Completed Health Check Export: $(date +%Y%m%d-%H%M%0S)" | tee -a "$mainlog"

sed -i 's/\/tmp\/EIHC-Logs/EIHC-Logs/g' "$mainlog"

# Time to wrap:
echo -e "Setting file ownership"
# set ownership and compress
chmod 775 $(find $LOGDIR/ -type d)
chmod 666 $(find $LOGDIR/ -type f)
chown -R silentdefense:silentdefense "$LOGDIR"

echo -e "Creating export file"
tar -czf "$TARBALL" "$EIHCLOGS" &
SPINNER

chown -R silentdefense:silentdefense "$TARBALL"

LINE
echo -e "Please send this file to your Forescout Professional Services Engineer:"
echo "$TARBALL"
echo -e ""
echo -e "Files are also in the local $LOGDIR directory"
LINE

ls -lh "$TARBALL" | awk '{print $9 " (" $5 ")"}'

