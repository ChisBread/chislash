#!/bin/bash
setroute() {
#在nat表中新建一个clash规则链
iptables -t nat -N CLASH
#排除环形地址与保留地址，匹配之后直接RETURN
iptables -t nat -A CLASH -d 0.0.0.0/8 -j RETURN
iptables -t nat -A CLASH -d 10.0.0.0/8 -j RETURN
iptables -t nat -A CLASH -d 127.0.0.0/8 -j RETURN
iptables -t nat -A CLASH -d 169.254.0.0/16 -j RETURN
iptables -t nat -A CLASH -d 172.16.0.0/12 -j RETURN
iptables -t nat -A CLASH -d 192.168.0.0/16 -j RETURN
iptables -t nat -A CLASH -d 224.0.0.0/4 -j RETURN
iptables -t nat -A CLASH -d 240.0.0.0/4 -j RETURN
#重定向tcp流量到本机$CLASH_REDIR_PORT端口
iptables -t nat -A CLASH -p tcp -j REDIRECT --to-port $CLASH_REDIR_PORT
#拦截外部tcp数据并交给clash规则链处理
iptables -t nat -A PREROUTING -p tcp -j CLASH

#在nat表中新建一个clash_dns规则链
iptables -t nat -N CLASH_DNS
#清空clash_dns规则链
iptables -t nat -F CLASH_DNS
#重定向udp流量到本机1053端口(DNS)
iptables -t nat -A CLASH_DNS -p udp -j REDIRECT --to-port 1053
#抓取本机产生的53端口流量交给clash_dns规则链处理
iptables -t nat -I OUTPUT -p udp --dport 53 -j CLASH_DNS
#拦截外部udp的53端口流量交给clash_dns规则链处理
iptables -t nat -I PREROUTING -p udp --dport 53 -j CLASH_DNS
}
unsetroute() {
while :
do
iptables -t nat -D PREROUTING -p tcp -j CLASH
if [ "$?" == "0" ]; then continue; fi
iptables -t nat -D OUTPUT -p udp --dport 53 -j CLASH_DNS
if [ "$?" == "0" ]; then continue; fi
iptables -t nat -D PREROUTING -p udp --dport 53 -j CLASH_DNS
if [ "$?" == "0" ]; then continue; fi
iptables -t nat -F CLASH
iptables -t nat -X CLASH
iptables -t nat -F CLASH_DNS
iptables -t nat -X CLASH_DNS
break;
done
}
#清理
_term() {
  unsetroute
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
setroute
python3 /default/clash/utils/override.py "/etc/clash/config.yaml" "$CLASH_HTTP_PORT" "$CLASH_SOCKS_PORT" "$CLASH_REDIR_PORT" "$CLASH_MIXED_PORT" "$LOG_LEVEL"
clash -d /etc/clash -ext-ctl "0.0.0.0:$DASH_PORT" -ext-ui /etc/clash/dashboard/public 2>&1 >/etc/clash/clash.log &
echo $! > /var/clash.pid
echo "Dashboard Address: http://YOUR_IP:$DASH_PORT/ui"
tail -f /etc/clash/clash.log &
wait