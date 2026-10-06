#!/bin/bash
BAKIFS=$IFS
IFS=$'\n'
c2_server_key="your.server.key"
c2_client_key="your.client.key"
ip="127.0.0.1"
c2serverusername="serverusername"
c2clientusername="clientusername"

# Check if a device was passed as command line argument
if [ $# -eq 1 ]; then
    selected=$1
else
    echo "Loading device list..."
    echo ""
    port_suffixes=`ssh -o StrictHostKeyChecking=no $c2serverusername@$ip -i $c2_server_key -p 443 "active_c2_tagged.sh"`

    echo "Available Devices:"
    for suffix in $port_suffixes; do
      echo "$suffix"
    done

    echo ""
    read -p 'Device: ' selected
fi

ssh -o StrictHostKeyChecking=no -n -tt -L $selected:localhost:$selected $c2serverusername@$ip -p 443 -i $c2_server_key > /dev/null &
result=$?
map_pid=$!

if [ $result -eq 0 ]; then
  echo -ne "Initializing Map.\r"
  sleep 1
  echo -ne "Initializing Map..\r"
  sleep 1
  echo -ne " \r"
  echo "Map Complete"
else
  echo "Map Failed, exiting..."
  exit 1
fi

ssh -o StrictHostKeyChecking=no -q -CNTD `echo "${selected}+10000" | bc` $c2clientusername@localhost -p $selected -i $c2_client_key &
result=$?
proxy_pid=$!

if [ $result -eq 0 ]; then
  echo "Proxy Successful"
else
  echo "Proxy Failed"
fi

#Uncomment below if you are seeeing connection to localhost refused #typically a long RTT
#sleep 15

echo "Dropping into shell..."
ssh -o StrictHostKeyChecking=no $c2clientusername@localhost -p $selected -i $c2_client_key

echo "Cleaning up..."
echo "Killing map and proxy for device $selected"
kill $map_pid
kill $proxy_pid
IFS=$BAKIFS
