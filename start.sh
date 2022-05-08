#!/bin/bash
setroute() {
    # CLASH rules on nat，mangle
    iptables -t nat -N CLASH
    iptables -t mangle -N CLASH
    ################## TCP转发 ######################
    # Bypass private IP address ranges
    iptables -t nat -A CLASH -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A CLASH -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A CLASH -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A CLASH -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A CLASH -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A CLASH -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A CLASH -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A CLASH -d 240.0.0.0/4 -j RETURN
    # Redirect(TCP) ignore clash
    iptables -t nat -A CLASH -p tcp -j REDIRECT --to-port $CLASH_REDIR_PORT
    iptables -t nat -A PREROUTING -p tcp -j CLASH
    ################## UDP转发 ######################
    # IP rules
    ip rule add fwmark 1 table 100
    ip route add local default dev lo table 100

    # Bypass private IP address ranges
    iptables -t mangle -N CLASH
    iptables -t mangle -A CLASH -d 0.0.0.0/8 -j RETURN
    iptables -t mangle -A CLASH -d 10.0.0.0/8 -j RETURN
    iptables -t mangle -A CLASH -d 127.0.0.0/8 -j RETURN
    iptables -t mangle -A CLASH -d 169.254.0.0/16 -j RETURN
    iptables -t mangle -A CLASH -d 172.16.0.0/12 -j RETURN
    iptables -t mangle -A CLASH -d 192.168.0.0/16 -j RETURN
    iptables -t mangle -A CLASH -d 224.0.0.0/4 -j RETURN
    iptables -t mangle -A CLASH -d 240.0.0.0/4 -j RETURN

    # Redirect(UDP) ignore clash
    iptables -t mangle -A CLASH -p udp -j TPROXY --on-port $CLASH_REDIR_PORT --tproxy-mark 1
    iptables -t mangle -A PREROUTING -p udp -j CLASH
    ################## DNS转发 ######################
    iptables -t nat -N CLASH_DNS
    iptables -t nat -F CLASH_DNS
    # Redirect(DNS)
    iptables -t nat -A CLASH_DNS -p udp -j REDIRECT --to-port 1053
    iptables -t nat -I OUTPUT -p udp --dport 53 -j CLASH_DNS
    iptables -t nat -I PREROUTING -p udp --dport 53 -j CLASH_DNS
    #iptables -t nat -I PREROUTING -p udp --dport 53 -d 192.168.0.0/16 -j REDIRECT --to 1053
}
unsetroute() {
    while :
    do
        iptables -t nat -D PREROUTING -p tcp -j CLASH 2>&1 >/dev/null
        if [ "$?" == "0" ]; then continue; fi
        iptables -t mangle -D PREROUTING -p udp -j CLASH 2>&1 >/dev/null
        if [ "$?" == "0" ]; then continue; fi
        iptables -t nat -D OUTPUT -p udp --dport 53 -j CLASH_DNS 2>&1 >/dev/null
        if [ "$?" == "0" ]; then continue; fi
        iptables -t nat -D PREROUTING -p udp --dport 53 -j CLASH_DNS 2>&1 >/dev/null
        if [ "$?" == "0" ]; then continue; fi
        iptables -t nat -F CLASH
        iptables -t nat -X CLASH
        iptables -t mangle -F CLASH
        iptables -t mangle -X CLASH
        iptables -t nat -F CLASH_DNS
        iptables -t nat -X CLASH_DNS
        break;
    done
}
#清理
_term() {
    echo "Caught SIGTERM signal!"
    echo "Tell the clash session to shut down."
    pid=`cat /var/clash.pid`
    # terminate when the clash-daemon process dies
    tail --pid=${pid} -f /dev/null
    if [ "$IPROUTE" == "1" ]; then
        echo "unset iproutes ..."
        unsetroute 2>&1 >/dev/null
        echo "done."
    fi
}
trap _term SIGTERM SIGINT
# 初始化 /etc/clash
if [ ! -f "/etc/clash/config.yaml" ]; then
    echo "mixed-port: 7890" > /etc/clash/config.yaml
fi
if [ ! -f "/etc/clash/Country.mmdb" ]; then
    cp -arp /default/clash/Country.mmdb /etc/clash/Country.mmdb
fi
if [ ! -d "/etc/clash/dashboard" ]; then
    cp -arp /default/clash/dashboard /etc/clash/dashboard
fi
if [ "$IPROUTE" == "1" ]; then
    echo "set iproutes ..."
    setroute
    echo "done."
fi
python3 /default/clash/utils/override.py "/etc/clash/config.yaml" "$CLASH_HTTP_PORT" "$CLASH_SOCKS_PORT" "$CLASH_REDIR_PORT" "$CLASH_MIXED_PORT" "$LOG_LEVEL"
/usr/bin/clash -d /etc/clash -ext-ctl "0.0.0.0:$DASH_PORT" -ext-ui /etc/clash/dashboard/public 2>&1 >/etc/clash/clash.log &
echo $! > /var/clash.pid
echo "Dashboard Address: http://YOUR_IP:$DASH_PORT/ui"
tail -f /etc/clash/clash.log &
wait