#!/usr/bin/env bash

# set -ex

# ENABLE ipv4 forward
sysctl -w net.ipv4.ip_forward=1

# ROUTE RULES
ip rule add fwmark 666 lookup 666
ip route add local 0.0.0.0/0 dev lo table 666

# CLASH 链负责处理转发流量 
iptables -t mangle -N CLASH
iptables -t mangle -F CLASH
# 目标地址为局域网或保留地址的流量跳过处理
# 保留地址参考: https://zh.wikipedia.org/wiki/%E5%B7%B2%E5%88%86%E9%85%8D%E7%9A%84/8_IPv4%E5%9C%B0%E5%9D%80%E5%9D%97%E5%88%97%E8%A1%A8
iptables -t mangle -A CLASH -d 0.0.0.0/8 -j RETURN
iptables -t mangle -A CLASH -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A CLASH -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A CLASH -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A CLASH -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A CLASH -d 169.254.0.0/16 -j RETURN

iptables -t mangle -A CLASH -d 224.0.0.0/4 -j RETURN
iptables -t mangle -A CLASH -d 240.0.0.0/4 -j RETURN

# 其他所有流量转向到 $CLASH_TPROXY_PORT 端口，并打上 mark
iptables -t mangle -A CLASH -p tcp -j TPROXY --on-port $CLASH_TPROXY_PORT --tproxy-mark 666
if [ "$UDP_PROXY" == "1" ]; then
    iptables -t mangle -A CLASH -p udp -j TPROXY --on-port $CLASH_TPROXY_PORT --tproxy-mark 666
fi
# 转发所有 DNS 查询到 1053 端口
# 此操作会导致所有 DNS 请求全部返回虚假 IP(fake ip 198.18.0.1/16)
# iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to 1053

# 如果想要 dig 等命令可用, 可以只处理 DNS SERVER 设置为当前内网的 DNS 请求
# iptables -t nat -I PREROUTING -p udp --dport 53 -d 192.168.0.0/16 -j REDIRECT --to 1053
iptables -t nat -N CLASH_DNS_LOCAL
iptables -t nat -N CLASH_DNS_EXTERNAL
iptables -t nat -F CLASH_DNS_LOCAL
iptables -t nat -F CLASH_DNS_EXTERNAL

iptables -t nat -A CLASH_DNS_LOCAL -p udp --dport 53 -j REDIRECT --to-ports 1053
iptables -t nat -A CLASH_DNS_LOCAL -p tcp --dport 53 -j REDIRECT --to-ports 1053
iptables -t nat -A CLASH_DNS_LOCAL -m owner --uid-owner clash -j RETURN

iptables -t nat -A CLASH_DNS_EXTERNAL -p udp --dport 53 -j REDIRECT --to-ports 1053
iptables -t nat -A CLASH_DNS_EXTERNAL -p tcp --dport 53 -j REDIRECT --to-ports 1053

iptables -t nat -I OUTPUT -p udp -j CLASH_DNS_LOCAL
iptables -t nat -I PREROUTING -p udp -j CLASH_DNS_EXTERNAL

# 最后让所有流量通过 CLASH 链进行处理
iptables -t mangle -A PREROUTING -j CLASH

# CLASH_LOCAL 链负责处理网关本身发出的流量
iptables -t mangle -N CLASH_LOCAL
iptables -t mangle -F CLASH_LOCAL
# nerdctl 容器流量重新路由
#iptables -t mangle -A CLASH_LOCAL -i nerdctl2 -p udp -j MARK --set-mark 666
#iptables -t mangle -A CLASH_LOCAL -i nerdctl2 -p tcp -j MARK --set-mark 666

# 跳过内网流量
iptables -t mangle -A CLASH_LOCAL -d 0.0.0.0/8 -j RETURN
iptables -t mangle -A CLASH_LOCAL -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A CLASH_LOCAL -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A CLASH_LOCAL -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A CLASH_LOCAL -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A CLASH_LOCAL -d 169.254.0.0/16 -j RETURN

iptables -t mangle -A CLASH_LOCAL -d 224.0.0.0/4 -j RETURN
iptables -t mangle -A CLASH_LOCAL -d 240.0.0.0/4 -j RETURN

# 为本机发出的流量打 mark
iptables -t mangle -A CLASH_LOCAL -p tcp -j MARK --set-mark 666
if [ "$UDP_PROXY" == "1" ]; then
    iptables -t mangle -A CLASH_LOCAL -p udp -j MARK --set-mark 666
fi
# 跳过 CLASH 程序本身发出的流量, 防止死循环(CLASH 程序需要使用 "CLASH" 用户启动) 
iptables -t mangle -A OUTPUT -p tcp -m owner --uid-owner clash -j RETURN
if [ "$UDP_PROXY" == "1" ]; then
    iptables -t mangle -A OUTPUT -p udp -m owner --uid-owner clash -j RETURN
fi
# 让本机发出的流量跳转到 CLASH_LOCAL
# CLASH_LOCAL 链会为本机流量打 mark, 打过 mark 的流量会重新回到 PREROUTING 上
iptables -t mangle -A OUTPUT -j CLASH_LOCAL

# 修复 ICMP(ping)
# 这并不能保证 ping 结果有效(CLASH 等不支持转发 ICMP), 只是让它有返回结果而已
# --to-destination 设置为一个可达的地址即可
sysctl -w net.ipv4.conf.all.route_localnet=1
iptables -t nat -A PREROUTING -p icmp -d 198.18.0.0/16 -j DNAT --to-destination 127.0.0.1