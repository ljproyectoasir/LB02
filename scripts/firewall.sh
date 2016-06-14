#!/bin/bash

### Declaracion de arrays ###

declare -a TCP_IN
declare -a TCP_IN_SOURCE
declare -a TCP_IN_DEST

declare -a UDP_IN
declare -a UDP_IN_SOURCE
declare -a DUP_IN_DEST

declare -a TCP_OUT
declare -a TCP_OUT_DEST

declare -a UDP_OUT
declare -a UDP_OUT_DEST

### PUERTOS ###
DNS=53
FTP=21
FTP_DATA=20
FTP_PASSIVE=45000:45500
HTTP=80
HTTPS=443
NTP=123
NRPE=5666
SSH=22
MYSQL=3306
REDIS=6379
SENTINEL=26379
HEARTBEAT=694
HAPROXY_STATS=1935


### IPs ###
IP_LOCAL_1='192.168.1.220'
IP_LOCAL_2='192.168.1.215'
IP_LOCAL_3='10.0.10.10'
NAGIOS_1='130.211.105.161'
NAGIOS_2='52.48.78.193'
ALL='0.0.0.0/0'
RED_LOCAL='10.0.0.0/8'

### Permitir trafico ###

ICMP='yes'
NAT='no'
FORWARD='no'

### Politicas ###
P_INPUT='DROP'
P_OUTPUT='DROP'
P_FORWARD='DROP'


### Servicios TCP que corren en el servidor (input) ###
TCP_IN=(${HTTP} ${HTTPS} ${HAPROXY_STATS} ${NRPE} ${NRPE})
TCP_IN_SOURCE=(${ALL} ${ALL} ${ALL} ${ALL} ${NAGIOS_1} ${NAGIOS_2})
TCP_IN_DEST=(${ALL} ${ALL} ${ALL} ${ALL} ${IP_LOCAL_1} ${IP_LOCAL_1})

### Servicios UDP que corren en el servidor (input) ###
UDP_IN=(${HEARTBEAT})
UDP_IN_SOURCE=(${ALL})
UDP_IN_DEST=(${ALL})

### Servicios TCP a los que accede el servidor (output) ###
TCP_OUT=(${HTTP} ${HTTPS})
TCP_OUT_DEST=(${ALL} ${ALL})

### Servicios UDP a los que accede el servidor (output) ###
UDP_OUT=(${HEARTBEAT})
UDP_OUT_DEST=(${ALL})

###############################################################################
###############################################################################
###############################################################################

echo "Borrando reglas antiguas"

### FLUSH de reglas ###
iptables -F
iptables -X
iptables -Z
iptables -t nat -F

echo "Aplicando politicas por defecto"  

### Politica por defecto ###
iptables -P INPUT $P_INPUT
iptables -P OUTPUT $P_OUTPUT
iptables -P FORWARD $P_FORWARD


### Perminir tradfico icmp ###
if [ $ICMP == 'yes' ]; then
	iptables -A INPUT -p icmp -j ACCEPT
	iptables -A OUTPUT -p icmp -j ACCEPT
	echo "Ping activado"
	fi
### Permitir reenvio, routing ###
if [ $FORWARD == 'yes' ]; then
	echo 1 > /proc/sys/net/ipv4/ip_forward
	echo "Reenvio activado"
	fi

### Habilitar nat en la red local ###
if [ $NAT == 'yes' ]; then
	echo "Aplicando NAT"
	iptables -t nat -A POSTROUTING -s $RED_LOCAL -o eth0 -j MASQUERADE
	iptables -A INPUT -s $RED_LOCAL -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
	iptables -A OUTPUT -s $RED_LOCAL -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
	fi

echo "Permitiendo trafico local, ssh y resolucion dns"

### Permitir conexiones locales ###
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -i $IP_LOCAL_1 -j ACCEPT

if [ -n $IP_LOCAL_2 ];then
	iptables -A INPUT -i $IP_LOCAL_2 -j ACCEPT
	echo "IP 2 activa de entrada"
fi
if [ -n $IP_LOCAL_3 ];then
        iptables -A INPUT -i $IP_LOCAL_3 -j ACCEPT
        echo "IP 3 activa de entrada"
fi

### Permitir conexiones establecidas, ssh y resolucion dns  ###
iptables -A INPUT -p tcp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -o $IP_LOCAL_1 -j ACCEPT

if [ -n $IP_LOCAL_2 ];then
	iptables -A OUTPUT -o $IP_LOCAL_2 -j ACCEPT
	echo "IP 2 activa para salida"
fi
if [ -n $IP_LOCAL_3 ];then
        iptables -A OUTPUT -o $IP_LOCAL_3 -j ACCEPT
        echo "IP 3 activa para salida"
fi

iptables -A OUTPUT -p tcp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

echo "Aplicando reglas de trafico entrante TCP"

### TCP INPUT  ###
CONT1=${#TCP_IN[@]}
#echo $CONT1
for (( i=0 ; i<$CONT1 ; i=i+1 )); do
#	echo ${TCP_IN[i]}
#	echo ${TCP_IN_SOURCE[i]}
#	echo ${TCP_IN_DEST[i]}
iptables -A INPUT -p tcp -s ${TCP_IN_SOURCE[i]} -d ${TCP_IN_DEST[i]} --dport ${TCP_IN[i]} -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
done

echo "Aplicando reglas de trafico entrante UDP"

### UDP INPUT  ###
CONT2=${#UDP_IN[@]}
for (( i=0 ; i<$CONT2 ; i=i+1 )); do
#        echo ${UDP_IN[i]}
#        echo ${UDP_IN_SOURCE[i]}
#        echo ${UDP_IN_DEST[i]}
iptables -A INPUT -p udp -s ${UDP_IN_SOURCE[i]} -d ${UDP_IN_DEST[i]} --dport ${UDP_IN[i]} -j ACCEPT
done

echo "Aplicando reglas de trafico saliente TCP"

### TCP OUTPUT  ###
CONT3=${#TCP_OUT[@]}
#echo $CONT3
for (( i=0 ; i<$CONT3 ; i=i+1 )); do
#        echo ${TCP_OUT[i]}
#        echo ${TCP_OUT_SOURCE[i]}
#        echo ${TCP_OUT_DEST[i]}
iptables -A OUTPUT -p tcp -d ${TCP_OUT_DEST[i]} --dport ${TCP_OUT[i]} -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
done

echo "Aplicando reglas de trafico saliente UDP"

### UDP OUTPUT  ###
CONT4=${#UDP_OUT[@]}
for (( i=0 ; i<$CONT4 ; i=i+1 )); do
#        echo ${UDP_OUT[i]}
#        echo ${UDP_OUT_SOURCE[i]}
#        echo ${UDP_OUT_DEST[i]}
iptables -A OUTPUT -p udp -d ${UDP_OUT_DEST[i]} --dport ${UDP_OUT[i]} -j ACCEPT
done

/etc/init.d/networking restart
