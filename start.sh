#!/bin/bash
setroute() {
    /setup_iptables.sh
}
unsetroute() {
    /unset_iptables.sh
}
#清理
_term() {
    echo "Caught SIGTERM signal!"
    echo "Tell the clash session to shut down."
    pid=`cat /var/clash.pid`
    # terminate when the clash-daemon process dies
    __=`kill -9 ${pid} 2>&1 >/dev/null`
    tail --pid=${pid} -f /dev/null
    if [ "$IP_ROUTE" == "1" ]; then
        echo "unset iproutes ..."
        __=`unsetroute 2>&1 >/dev/null`
        echo "done."
    fi
    mv /etc/clash/config.yaml.org /etc/clash/config.yaml
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
if [ "$IP_ROUTE" == "1" ]; then
    echo "set iproutes ..."
    __=`unsetroute 2>&1 >/dev/null`
    __=`setroute 2>&1 >/dev/null`
    echo "done."
fi
cp /etc/clash/config.yaml /etc/clash/config.yaml.org
python3 /default/clash/utils/override.py "/etc/clash/config.yaml" "$MUST_CONFIG" "$CLASH_HTTP_PORT" "$CLASH_SOCKS_PORT" "$CLASH_TPROXY_PORT" "$CLASH_MIXED_PORT" "$LOG_LEVEL"
chmod -R a+rw /etc/clash
su - clash -c '/usr/bin/clash -d /etc/clash -ext-ctl "0.0.0.0:$DASH_PORT" -ext-ui /etc/clash/dashboard/public' 2>&1 >/etc/clash/clash.log &
echo $! > /var/clash.pid
echo "Dashboard Address: http://YOUR_IP:$DASH_PORT/ui"
tail -f /etc/clash/clash.log &
wait