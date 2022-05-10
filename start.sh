#!/usr/bin/env bash
set -eE
echolog() {
    echo -e "\033[32m[chislash log]\033[0m" $*
}
export -f echolog
echoerr() {
    echo -e "\033[31m[chislash log]\033[0m" $*
}
export -f echoerr
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
file_expired() {
    if [ ! -f "$1" ]; then
        echo -1
        exit 0
    fi
    if [ $2 -eq 0 ]; then
        echo 0
        exit 0
    fi
    last=`stat -c %Y $1`
    now=`date +%s`
    since=$(($now - $last))
    if [ $since -ge $2 ]; then
        echo -1
    else
        echo $(($2 - $since))
    fi
    exit 0
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
    pid=`cat /var/subconverter.pid` || true
    __=`kill -9 ${pid} 2>&1 >/dev/null` || true
    exit 0
}
trap _term SIGTERM SIGINT ERR
# 初始化 /etc/clash
if [ ! -f "/etc/clash/Country.mmdb" ]; then
    cp -arp /default/clash/Country.mmdb /etc/clash/Country.mmdb
fi
if [ ! -d "/etc/clash/dashboard" ]; then
    cp -arp /default/clash/dashboard /etc/clash/dashboard
fi
if [ ! -d "/etc/clash/subconverter" ]; then
    cp -arp /default/subconverter /etc/clash/subconverter
fi
chmod -R a+rw /etc/clash
# 启动订阅转换服务
if [ "$ENABLE_SUBCONV" == "1" ]; then
    echolog "启动订阅转换服务..."
    nohup /etc/clash/subconverter/subconverter >/etc/clash/subconverter.log 2>&1 &
    echo $! > /var/subconverter.pid
    while :
    do
        startup="`grep 'Startup completed.' /etc/clash/subconverter.log`" || true
        if [ "$startup" != "" ]; then
            echolog "订阅转换服务就绪"
            echolog $startup
            break
        fi
    done
fi
# 转换订阅
if [ "$SUBSCR_URLS" != "" ]; then
    SINCE=`file_expired /etc/clash/.subscr_expr $SUBSCR_EXPR`
    if [ "$SINCE" == "-1" ] || [ ! -f "/etc/clash/config.yaml" ]; then
        echolog "订阅已过期 重新订阅中..."
        # 如果依赖本地订阅, 但没有启动服务;
        if [ "`echo "$SUBSCR_URLS" |grep 'http://127.0.0.1:25500/sub'`" != "" ] && [ "$ENABLE_SUBCONV" != "1" ]; then
                echoerr "依赖本地订阅服务, 请设置ENABLE_SUBCONV=1"
                exit 1
        fi
        curl --get \
            --data-urlencode "target=clash" \
            --data-urlencode "url=$SUBSCR_URLS" \
            --data-urlencode "config=$REMOTE_CONV_RULE" \
            "$SUBCONV_URL" > /etc/clash/config.yaml
        touch /etc/clash/.subscr_expr
    else
        echolog "订阅有效 ${SINCE} 秒后重新订阅"
    fi
fi
python3 /default/clash/utils/override.py \
    "/etc/clash/config.yaml" \
    "$REQUIRED_CONFIG" \
    "$CLASH_HTTP_PORT" \
    "$CLASH_SOCKS_PORT" \
    "$CLASH_TPROXY_PORT" \
    "$CLASH_MIXED_PORT" \
    "$LOG_LEVEL" \
    "$IPV6_PROXY"
su - clash -c '/usr/bin/clash -d /etc/clash -ext-ctl '"0.0.0.0:$DASH_PORT"' -ext-ui /etc/clash/dashboard/public'  >/etc/clash/clash.log 2>&1 &
EXPID=$!
while :
do
    PID=`ps -def|grep -P '^clash'|awk '{print $2}'` || true
    PORT_EXIST=`ss -tlnp| awk '{print $4}'|grep -P ".*:$CLASH_TPROXY_PORT"` || true
    if [ "$PID" == "" ] || [ "$PORT_EXIST" == "" ]; then
        EXPID_EXIST=$(ps aux | awk '{print $2}'| grep -w $EXPID) || true
        if [ ! $EXPID_EXIST ];then
            echoerr "clash is not running"
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
    __=`unsetroute >/dev/null 2>&1` || true
    touch /tmp/setroute.log
    __=`setroute >/tmp/setroute.log 2>/tmp/setroute.err` || true
    cat /tmp/setroute.log | xargs -n 1 -P 10 -I {} bash -c 'echolog "$@"' _ {}
    cat /tmp/setroute.err | xargs -n 1 -P 10 -I {} bash -c 'echoerr "$@"' _ {}
    if [ "`cat /tmp/setroute.log|grep "tproxy is not supported" `" ]; then
        echoerr "tproxy is not supported"
        exit 1
    fi
    echolog "done."
fi
echolog "Dashboard Address: http://"`ip a | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' |head -n 1`":$DASH_PORT/ui"
nohup tail -f /etc/clash/clash.log | xargs -n 1 -P 10 -I {} bash -c 'echolog "$@"' _ {}  2>&1 &
wait