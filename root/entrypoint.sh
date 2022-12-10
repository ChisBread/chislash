#!/usr/bin/env bash
# line buffer
if [ yes != "$STDBUF" ]; then
    # exec 信号量捕获使能
    STDBUF=yes exec /usr/bin/stdbuf -oL -eL "$0"
    exit $?
fi
set -eE
cp -rf /myroot/etc/* /etc
cp -rf /myroot/bin/* /usr/bin
cp -rf /myroot/transparent_proxy /transparent_proxy
source /etc/utils.sh
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
if [ "${PREMIUM^^}" == "TRUE" ]; then
    cp /usr/bin/clash-premium /usr/bin/clash
else
    cp /usr/bin/clash-open /usr/bin/clash
fi
chmod -R a+rw /etc/clash

################### 生成config.yaml ###################
if [ "$SUBSCR_URLS" != "" ]; then
    export ENABLE_SUBCONV=1
fi
# 启动订阅转换服务
if [ "$ENABLE_SUBCONV" != "1" ]; then
    _=`rm /etc/supervisord.d/exporter.conf` || true
    _=`rm /etc/supervisord.d/subconverter.conf` || true
fi
echo 'export ENABLE_CLASH='"$ENABLE_CLASH" > /etc/envinit.sh
echo 'export REQUIRED_CONFIG='"$REQUIRED_CONFIG" >> /etc/envinit.sh
echo 'export CLASH_HTTP_PORT='"$CLASH_HTTP_PORT" >> /etc/envinit.sh
echo 'export CLASH_SOCKS_PORT='"$CLASH_SOCKS_PORT" >> /etc/envinit.sh
echo 'export CLASH_TPROXY_PORT='"$CLASH_TPROXY_PORT" >> /etc/envinit.sh
echo 'export CLASH_MIXED_PORT='"$CLASH_MIXED_PORT" >> /etc/envinit.sh
echo 'export DASH_PORT='"$DASH_PORT" >> /etc/envinit.sh
echo 'export DASH_PATH='"$DASH_PATH" >> /etc/envinit.sh
echo 'export IP_ROUTE='"$IP_ROUTE" >> /etc/envinit.sh
echo 'export UDP_PROXY='"$UDP_PROXY" >> /etc/envinit.sh
echo 'export IPV6_PROXY='"$IPV6_PROXY" >> /etc/envinit.sh
echo 'export PROXY_FWMARK='"$PROXY_FWMARK" >> /etc/envinit.sh
echo 'export PROXY_ROUTE_TABLE='"$PROXY_ROUTE_TABLE" >> /etc/envinit.sh
echo 'export LOG_LEVEL='"$LOG_LEVEL" >> /etc/envinit.sh
echo 'export SECRET='"$SECRET" >> /etc/envinit.sh
echo 'export ENABLE_SUBCONV='"$ENABLE_SUBCONV" >> /etc/envinit.sh
echo 'export SUBCONV_URL='"$SUBCONV_URL" >> /etc/envinit.sh
echo 'export SUBSCR_URLS='"$SUBSCR_URLS" >> /etc/envinit.sh
echo 'export SUBSCR_EXPR='"$SUBSCR_EXPR" >> /etc/envinit.sh
echo 'export REMOTE_CONV_RULE='"$REMOTE_CONV_RULE" >> /etc/envinit.sh
echo 'export EXPORT_DIR_PORT='"$EXPORT_DIR_PORT" >> /etc/envinit.sh
echo 'export EXPORT_DIR_BIND='"$EXPORT_DIR_BIND" >> /etc/envinit.sh
echo 'export NO_ENGLISH='"$NO_ENGLISH" >> /etc/envinit.sh
echo 'export PREMIUM='"$PREMIUM" >> /etc/envinit.sh
exec bash -c 'supervisord -c /etc/supervisord.conf -l /var/log/supervisord.log'