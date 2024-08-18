#!/bin/bash
# name: passup.sh
# created by: stak ovahflow
# modified: 2024-08-18

if [ $# -eq 0 ]
  then
    echo "Usage:"
    echo "$0 hosts.txt"
    exit
fi
HOSTSFILE="$1"

# Prompt the user for the username
read -p "Enter the username: " USERNAME

# Prompt the user for the current password securely
read -s -p "Enter the current password: " CURRENT_PASSWORD
echo

# Prompt the user for the new password securely
read -s -p "Enter the new password: " NEW_PASSWORD
echo

# Log file with date and time
#LOGFILE="password_change.log"
LOGFILE="password_change_$(date +'%Y%m%d_%H%M%S').log"

# Read the list of hosts
HOSTS=$(cat $HOSTSFILE)

# Loop through each host
for HOST in $HOSTS; do
  echo "Changing password for $USERNAME on $HOST" | tee -a $LOGFILE
  /usr/bin/expect << EOF >> $LOGFILE 2>&1
    log_user 1
    set timeout 10
    spawn ssh -o StrictHostKeyChecking=no $USERNAME@$HOST
    expect "*password:" { send "$CURRENT_PASSWORD\r" }
    expect "*\$ " { send "unset HISTFILE; passwd\r"; }
    expect {
      "*Permission denied*" {
        send_user "Login failed for $HOST: Incorrect username or password.\n"
        exit 1
      }
      "*Current password:" {
          send "$CURRENT_PASSWORD\r";
          exp_continue
      }
      "*New password:" {
          send "$NEW_PASSWORD\r"
          exp_continue
      }
      "*Retype new password:" {
          send "$NEW_PASSWORD\r"
          exp_continue
      }
      "*ssword unchanged*" {
        send_user "Password unchanged...\n"
        exit 1
      }
    }
    expect "*\$ " { send "exit\r" }
    expect eof
EOF

  if [ $? -eq 0 ]; then
    echo "Successfully changed password for $USERNAME on $HOST" | tee -a $LOGFILE
  else
    echo "Failed to change password for $USERNAME on $HOST" | tee -a $LOGFILE
  fi
done
