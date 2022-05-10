# chislash
- 开箱即用的clash镜像
# 警告
- 十分**不建议**在云服务器(甲骨文,AWS...)上使用！！ 任何意外情况都可能导致你的服务器失联
# 使用
- 一些细节
  - 透明代理: 容器自动映射路由表，劫持本地DNS流量实现本地透明代理; 亦可作为网关使用, 需要指定DNS为网关IP
  - 配置文件: 容器会修改部分用户配置来统一端口和部分高级配置(关闭容器后会恢复), utils/override.py中定义了本镜像修改用户配置的方式
- docker-compose
```yaml
version: "3.4"
services:
  chislash:
    image: chisbread/chislash
    container_name: chislash
    environment:
      - TZ=Asia/Shanghai       # optional
      - CLASH_HTTP_PORT=7890   # optional (default:7890)
      - CLASH_SOCKS_PORT=7891  # optional (default:7891)
      - CLASH_TPROXY_PORT=7892 # optional (default:7892)
      - CLASH_MIXED_PORT=7893  # optional (default:7893)
      - DASH_PORT=8080         # optional (default:8080) RESTful API端口(对应WebUI http://IP:8080/ui)
      - IP_ROUTE=1             # optional (default:1) 开启透明代理(本机透明代理/作为旁路网关)
      - UDP_PROXY=1            # optional (default:1) 开启透明代理-UDP转发(需要节点支持)
      - IPV6_PROXY=0           # optional (default:1) 开启IPv6透明代理
      - LOG_LEVEL=info         # optional (default:info) 日志等级
      - ENABLE_SUBCONV=1       # optional (default:1) 开启本地订阅转换服务, 指定SUBSCR_URLS, 且没有外部订阅转换服务时, 需要为1
      - SUBCONV_URL=http://127.0.0.1:25500/sub  # optional (default:"http://127.0.0.1:25500/sub") 订阅转换服务地址
      - SUBSCR_URLS=<URLs split by '|'>         # optional 订阅的节点链接, 多个链接用'|'分隔, 会覆盖原有的config.yaml
      - SUBSCR_EXPR=86400                       # optional (default:86400) 订阅过期时间(秒), 下次启动如果过期, 会重新订阅
      - REMOTE_CONV_RULE=<URL of remote rule>   # optional (default:ACL4SSR的ini规则链接) 订阅转换规则
      - REQUIRED_CONFIG=<path to required.yaml> # optional 不能被覆盖的设置项, 最高优先级 (e.g. /etc/clash/required.yaml)
    volumes:
      - <path to config>:/etc/clash # required config.yaml的存放路径
      - /dev:/dev                   # optional 用于自动挂载TPROXY模块
      - /lib/modules:/lib/modules   # optional 用于自动挂载TPROXY模块
    network_mode: "host"            # required 如果开启IP_ROUTE, 则必须是host
    privileged: true                # required 如果开启IP_ROUTE, 则必须是true
    restart: unless-stopped
```
- docker run (参考docker-compose)
```bash
sudo docker run --name chislash \
    --network="host" \
    --privileged \
    --restart unless-stopped -d \
    -v /path/to/etc/clash:/etc/clash \
    -v /dev:/dev \
    -v /lib/modules:/lib/modules \
    -e SUBSCR_URLS=<URLs split by '|'> \
    chisbread/chislash:latest
```
# 感谢
- https://github.com/Dreamacro/clash
- https://github.com/haishanh/yacd