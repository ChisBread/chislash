#!/usr/bin/env bash
set -eE
echolog() {
    echo -e "\033[32m[chislash log]\033[0m" $*
}
setroute() {
    /transparent_proxy/tproxy.start
    if [ "$IPV6_PROXY" == "1" ]; then
        /transparent_proxy/tproxy.start ipv6
    fi
}
unsetroute() {
    /transparent_proxy/tproxy.stop
    if [ "$IPV6_PROXY" == "1" ]; then
        /transparent_proxy/tproxy.stop ipv6
    fi
}
#清理
_term() {
    echolog "Caught SIGTERM signal!"
    echolog "Tell the clash session to shut down."
    pid=`cat /var/clash.pid` || true
    # terminate when the clash-daemon process dies
    __=`kill -9 ${pid} 2>&1 >/dev/null` || true
    tail --pid=${pid} -f /dev/null || true
    if [ "$IP_ROUTE" == "1" ]; then
        echolog "unset iproutes ..."
        __=`unsetroute 2>&1 >/dev/null` || true
        echolog "done."
    fi
    mv /etc/clash/config.yaml.org /etc/clash/config.yaml || true
    exit 0
}
trap _term SIGTERM SIGINT ERR
# 初始化 /etc/clash
if [ ! -f "/etc/clash/config.yaml" ]; then
    echolog "mixed-port: $CLASH_MIXED_PORT" > /etc/clash/config.yaml
fi
if [ ! -f "/etc/clash/Country.mmdb" ]; then
    cp -arp /default/clash/Country.mmdb /etc/clash/Country.mmdb
fi
if [ ! -d "/etc/clash/dashboard" ]; then
    cp -arp /default/clash/dashboard /etc/clash/dashboard
fi
cp /etc/clash/config.yaml /etc/clash/config.yaml.org
python3 /default/clash/utils/override.py "/etc/clash/config.yaml" "$MUST_CONFIG" "$CLASH_HTTP_PORT" "$CLASH_SOCKS_PORT" "$CLASH_TPROXY_PORT" "$CLASH_MIXED_PORT" "$LOG_LEVEL"
chmod -R a+rw /etc/clash
su - clash -c '/usr/bin/clash -d /etc/clash -ext-ctl '"0.0.0.0:$DASH_PORT"' -ext-ui /etc/clash/dashboard/public' 2>&1 >/etc/clash/clash.log &
EXPID=$!
while :
do
    PID=`ps -def|grep -P '^clash'|awk '{print $2}'` || true
    PORT_EXIST=`ss -tlnp| awk '{print $4}'|grep -P ".*:$CLASH_TPROXY_PORT"` || true
    if [ "$PID" == "" ] || [ "$PORT_EXIST" == "" ]; then
        EXPID_EXIST=$(ps aux | awk '{print $2}'| grep -w $EXPID) || true
        if [ ! $EXPID_EXIST ];then
            cat /etc/clash/clash.log
            exit 1
        fi
        echolog 'waiting for clash ...'
        sleep 1
        continue
    fi
    echo $PID > /var/clash.pid
    break
done
if [ "$IP_ROUTE" == "1" ]; then
    echolog "set iproutes ..."
    set +eE
    __=`unsetroute 2>&1 >/dev/null`
    set -eE
    __=`setroute 2>&1 >/dev/null`
    echolog "done."
fi
echolog "Dashboard Address: http://"`ip a | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' |head -n 1`":$DASH_PORT/ui"
tail -f /etc/clash/clash.log &
wait