#!/bin/bash
#清理
_term() {
  echo "Caught SIGTERM signal!"
  echo "Tell the clash session to shut down."
  pid=`cat /var/clash.pid`
  # terminate when the clash-daemon process dies
  tail --pid=${pid} -f /dev/null
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
clash -d /etc/clash -ext-ctl "0.0.0.0:$DASH_PORT" -ext-ui /etc/clash/dashboard/public &
echo $! > /var/clash.pid
echo "Dashboard Address: http://YOUR_IP:$DASH_PORT/ui"
wait