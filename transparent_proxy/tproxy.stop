#!/usr/bin/env bash

# set -ex

ip rule del fwmark 666 table 666 || true
ip route del local 0.0.0.0/0 dev lo table 666 || true

################ 清理DNS规则 ##################
while :
do
    iptables -t nat -D PREROUTING -p udp -j CLASH_DNS_EXTERNAL
    if [ "$?" == "0" ]; then continue; fi
    iptables -t nat -D OUTPUT -p udp -j CLASH_DNS_LOCAL
    if [ "$?" == "0" ]; then continue; fi
    iptables -t nat -D CLASH_DNS_EXTERNAL -p tcp --dport 53 -j REDIRECT --to-ports 1053
    if [ "$?" == "0" ]; then continue; fi
    iptables -t nat -D CLASH_DNS_EXTERNAL -p udp --dport 53 -j REDIRECT --to-ports 1053
    if [ "$?" == "0" ]; then continue; fi
    iptables -t nat -D CLASH_DNS_LOCAL -m owner --uid-owner clash -j RETURN
    if [ "$?" == "0" ]; then continue; fi
    iptables -t nat -D CLASH_DNS_LOCAL -p tcp --dport 53 -j REDIRECT --to-ports 1053
    if [ "$?" == "0" ]; then continue; fi
    iptables -t nat -D CLASH_DNS_LOCAL -p udp --dport 53 -j REDIRECT --to-ports 1053
    if [ "$?" == "0" ]; then continue; fi
break;
done
iptables -t nat -F CLASH_DNS_EXTERNAL
iptables -t nat -F CLASH_DNS_LOCAL
iptables -t nat -X CLASH_DNS_EXTERNAL || true
iptables -t nat -X CLASH_DNS_LOCAL || true

################ 清理TPROXY规则 ##################
while :
do
    iptables -t nat -D PREROUTING -p icmp -d 198.18.0.0/16 -j DNAT --to-destination 127.0.0.1
    if [ "$?" == "0" ]; then continue; fi
    iptables -t mangle -D OUTPUT -j CLASH_LOCAL
    if [ "$?" == "0" ]; then continue; fi
    iptables -t mangle -D OUTPUT -p tcp -m owner --uid-owner clash -j RETURN
    if [ "$?" == "0" ]; then continue; fi
    iptables -t mangle -D OUTPUT -p udp -m owner --uid-owner clash -j RETURN
    if [ "$?" == "0" ]; then continue; fi
    iptables -t mangle -D PREROUTING -j CLASH
    if [ "$?" == "0" ]; then continue; fi
    break;
done
iptables -t mangle -F CLASH
iptables -t mangle -F CLASH_LOCAL
iptables -t mangle -X CLASH || true
iptables -t mangle -X CLASH_LOCAL || true
