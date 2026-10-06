#!/usr/bin/env bash
c2num=$1
c2hostname=`cat /home/c2/c2untagged.txt | grep "^${c2num}," | cut -d"," -f2`
netstat -ln | grep -q "$c2num" &>>/dev/null
result=$?
if [ $result -eq 0 ]
then
echo "${c2num} - ${c2hostname}"
fi