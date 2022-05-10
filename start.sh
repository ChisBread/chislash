#!/usr/bin/env bash
# line buffer
if [ yes != "$STDBUF" ]; then
    # exec 信号量捕获使能
    STDBUF=yes exec /usr/bin/stdbuf -oL -eL "$0"
    exit $?
fi
# cleanup iptables
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
set -eE
LOCAL_IP="`ip a | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' |head -n 1`"
echolog() {
    echo -e "\033[32m[chislash log]\033[0m" $*
}
export -f echolog
echoerr() {
    echo -e "\033[31m[chislash err]\033[0m" $*
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
if [ ! -d "/etc/clash/exports" ]; then
    cp -arp /default/exports /etc/clash/exports
fi
if [ "$IP_ROUTE" == "1" ]; then
    setcap 'cap_net_admin,cap_net_bind_service=+ep' /usr/bin/clash
else
    setcap 'cap_net_admin,cap_net_bind_service=-ep' /usr/bin/clash
    CLASH_TPROXY_PORT=0
fi
chmod -R a+rw /etc/clash
################### 生成config.yaml ###################
# 启动订阅转换服务
if [ "$ENABLE_SUBCONV" == "1" ]; then
    echolog "启动订阅转换服务..."
    $NO_ENGLISH || echolog "Subconverter is starting"
    /etc/clash/subconverter/subconverter >/etc/clash/subconverter.log 2>&1 &
    echo $! > /var/subconverter.pid
    while :
    do
        startup="`grep 'Startup completed.' /etc/clash/subconverter.log`" || true
        if [ "$startup" != "" ]; then
            echolog "订阅转换服务就绪"
            $NO_ENGLISH || echolog "Subconverter is ready"
            echolog "[subconverter] "$startup
            break
        fi
    done
    # 启动规则文件服务(用于存放自定义订阅转换规则ini)
    echolog "启动规则文件服务..."
    $NO_ENGLISH || echolog "RulesExporter is starting"
    python3 -u -m http.server $EXPORT_DIR_PORT -b $EXPORT_DIR_BIND --directory /etc/clash/exports >/etc/clash/rulesexporter.log 2>&1 &
    echo $! > /var/rulesexporter.pid
    while :
    do
        startup="`grep 'Serving HTTP on' /etc/clash/rulesexporter.log`" || true
        if [ "$startup" != "" ]; then
            echolog "规则文件服务就绪"
            $NO_ENGLISH || echolog "RulesExporter is ready"
            echolog "[rulesexporter] "$startup
            break
        fi
    done
fi
# 转换订阅
if [ "$SUBSCR_URLS" != "" ]; then
    SINCE=`file_expired /etc/clash/.subscr_expr $SUBSCR_EXPR`
    echolog `echo "转换服务: $SUBCONV_URL" | sed -r "s/(127.0.0.1|localhost)/$LOCAL_IP/g"`
    echolog `echo "规则服务: http://$EXPORT_DIR_BIND:$EXPORT_DIR_PORT/ACL4SSR/Clash/config/" | sed -r "s/(127.0.0.1|0.0.0.0)/$LOCAL_IP/g"`
    echolog `echo "转换规则: $REMOTE_CONV_RULE" | sed -r "s/(127.0.0.1|localhost)/$LOCAL_IP/g"`
    $NO_ENGLISH || echolog `echo "Subconverter  : $SUBCONV_URL" | sed -r "s/(127.0.0.1|localhost)/$LOCAL_IP/g"`
    $NO_ENGLISH || echolog `echo "RulesExporter : http://$EXPORT_DIR_BIND:$EXPORT_DIR_PORT/ACL4SSR/Clash/config/" | sed -r "s/(127.0.0.1|0.0.0.0)/$LOCAL_IP/g"`
    $NO_ENGLISH || echolog `echo "SubconvertRule: $REMOTE_CONV_RULE" | sed -r "s/(127.0.0.1|localhost)/$LOCAL_IP/g"`
    if [ "$SINCE" == "-1" ] || [ ! -f "/etc/clash/config.yaml" ]; then
        echolog "订阅已过期 重新订阅中... "
        $NO_ENGLISH || echolog "Subscription has expired, re-subscribing..."
        # 如果依赖本地订阅, 但没有启动服务;
        if [ "`echo "$SUBSCR_URLS" |grep 'http://127.0.0.1:25500/sub'`" != "" ] && [ "$ENABLE_SUBCONV" != "1" ]; then
            echoerr "依赖本地订阅转换服务, 请设置ENABLE_SUBCONV=1"
            $NO_ENGLISH || echoerr "Please set ENABLE_SUBCONV=1 to enable local subconverter"
            exit 1
        fi
        curl -s --get \
            --data-urlencode "target=clash" \
            --data-urlencode "url=$SUBSCR_URLS" \
            --data-urlencode "config=$REMOTE_CONV_RULE" \
            "$SUBCONV_URL" > /etc/clash/config.yaml.download
        # 错误订阅/转换数据
        VALID="`cat /etc/clash/config.yaml.download | grep -P '(bind-address|mode|port|rules)'`" || true
        if [ "$?" != "0" ] || [ "$VALID" == "" ]; then
            mv /etc/clash/config.yaml.download /etc/clash/config.yaml.wrong
            echoerr "节点订阅失败"
            $NO_ENGLISH || echoerr "Subscription failed"
            exit 1
        fi
        mv /etc/clash/config.yaml.download /etc/clash/config.yaml
        touch /etc/clash/.subscr_expr
    else
        echolog "订阅有效, ${SINCE} 秒后重新订阅"
        $NO_ENGLISH || echolog "Subscription expires after ${SINCE} seconds"
    fi
fi
echolog "使用环境变量覆盖config.yaml设置"
$NO_ENGLISH || echolog "Override config.yaml with environment variables"
python3 /default/clash/utils/override.py \
    "/etc/clash/config.yaml" \
    "$REQUIRED_CONFIG" \
    "$CLASH_HTTP_PORT" \
    "$CLASH_SOCKS_PORT" \
    "$CLASH_TPROXY_PORT" \
    "$CLASH_MIXED_PORT" \
    "$LOG_LEVEL" \
    "$IPV6_PROXY"
################### 启动clash服务 ###################
echolog "Clash启动中..."
$NO_ENGLISH || echolog "Clash is starting ..."
su - clash -c "/usr/bin/clash -d /etc/clash -ext-ctl 0.0.0.0:$DASH_PORT -ext-ui $DASH_PATH"  >/etc/clash/clash.log 2>&1 &
EXPID=$!
# 等待,直到SOCKS端口被监听, 或者clash启动失败
while :
do
    PID=`ps -def|grep -P '^clash'|awk '{print $2}'` || true
    PORT_EXIST=`ss -tlnp | awk '{print $4}' | grep -P ".*:$CLASH_SOCKS_PORT" | head -n 1` || true
    if [ "$PID" == "" ] || [ "$PORT_EXIST" == "" ]; then
        EXPID_EXIST=$(ps aux | awk '{print $2}'| grep -w $EXPID) || true
        if [ ! $EXPID_EXIST ];then
            echoerr "clash is not running"
            if [ "`cat /etc/clash/clash.log| grep 'Operation not permitted'`" != "" ]; then
                echoerr "privileged must be true"
            fi
            exit 1
        fi
        sleep 1
        continue
    fi
    echo $PID > /var/clash.pid
    break
done
echolog "Clash已就绪"
$NO_ENGLISH || echolog "Clash is ready"

if [ "$IP_ROUTE" == "1" ]; then
    echolog "设置路由规则..."
    $NO_ENGLISH || echolog "Set iproutes ..."
    __=`unsetroute >/dev/null 2>&1` || true
    touch /tmp/setroute.log
    __=`setroute >/tmp/setroute.log 2>/tmp/setroute.err` || true
    cat /tmp/setroute.log | xargs -n 1 -P 10 -I {} bash -c 'echolog "[setroute] $@"' _ {}
    cat /tmp/setroute.err | xargs -n 1 -P 10 -I {} bash -c 'echoerr "[setroute] $@"' _ {}
    if [ "`cat /tmp/setroute.log|grep "tproxy is not supported" `" ]; then
        echoerr "系统可能不支持TProxy, 无法设置透明代理"
        $NO_ENGLISH || echoerr "TProxy is not supported"
        exit 1
    fi
fi
echolog "Clash控制面板: http://$LOCAL_IP:$DASH_PORT/ui"
$NO_ENGLISH || echolog "Dashboard: http://$LOCAL_IP:$DASH_PORT/ui"
tail -f /etc/clash/clash.log \
    | grep -v 'Start initial compatible provider' \
    | xargs -n 1 -P 10 -I {} bash -c 'echolog "$@"' _ {}  2>&1 &
wait