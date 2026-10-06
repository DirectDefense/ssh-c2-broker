#!/usr/bin/env bash
for c2 in `netstat -ln | grep -w 3.... | grep tcp | cut -f2 -d: | cut -f1 -d" " | sort`
	do
		c2data=`cat /home/c2/c2untagged.txt | grep "^${c2},"`
		c2num=`echo "$c2data" | cut -d"," -f1`
		c2hostname=`echo "$c2data" | cut -d"," -f2`
		c2tagged=`grep -w "$c2hostname" /home/c2/c2database.txt | cut -d, -f3`
		netstat -ln | grep -q "$c2" &>>/dev/null
		result=$?
		if [ $result -eq 0 ]
			then
			echo "${c2num} - ${c2hostname} - ${c2tagged}"
			fi
	done