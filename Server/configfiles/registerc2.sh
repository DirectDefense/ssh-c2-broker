#!/usr/bin/env bash
hostname="$1"
tag="$2"
if [[ -z "$hostname" || -z "$tag" ]]; then
  echo "Usage: $0 <hostname> <tag>" >&2
  exit 1
fi
# assign or retrieve c2 port number for this hostname
if grep -q ",$hostname$" /home/c2/c2untagged.txt; then
  line="$(grep ",$hostname$" /home/c2/c2untagged.txt | sort -r | head -n1)"
  c2="$(echo "$line" | cut -d',' -f1)"
else
  c2="$(echo "$(tail -n1 /home/c2/lastc2.txt)+1" | bc)"
  echo "$c2,$hostname" >> /home/c2/c2untagged.txt
  echo "$c2" >> /home/c2/lastc2.txt
fi
echo "$c2"
# merge untagged entries into the database then apply the tag
cut -d',' -f1,2 /home/c2/c2database.txt > /home/c2/c2database.tmp
grep -w -x -v -f /home/c2/c2database.tmp /home/c2/c2untagged.txt >> /home/c2/c2database.txt

dbline="$(cut -d',' -f1,2 /home/c2/c2database.txt | grep -i "$hostname")"
sed -i "/$dbline/c\\${dbline},$tag" /home/c2/c2database.txt