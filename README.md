# chislash
- 开箱即用的clash镜像

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
      - TZ=Asia/Shanghai        # optional
      - CLASH_HTTP_PORT=7890    # optional (default:7890)
      - CLASH_SOCKS_PORT=7891   # optional (default:7891)
      - CLASH_TPROXY_PORT=7892  # optional (default:7892)
      - CLASH_MIXED_PORT=7893   # optional (default:7893)
      - DASH_PORT=8080          # optional (default:8080) RESTful API端口(同时也是Web UI端口 e.g. http://IP:8080/ui)
      - IP_ROUTE=1              # optional (default:1) 开启透明代理
      - UDP_PROXY=1             # optional (default:1) 开启透明代理-UDP转发(当代理节点不支持UDP时,可关闭)
      - LOG_LEVEL=info          # optional (default:info) 日志等级
    volumes:
      - <path to config>:/etc/clash # required config.yaml的存放路径
    network_mode: "host"            # required 如果开启IP_ROUTE, 则必须是host
    privileged: true                # required 如果开启IP_ROUTE, 则必须是true
    restart: unless-stopped
```
- docker run (参考docker-compose)
```bash
sudo docker run --privileged --network="host" --name chislash --restart unless-stopped -d \
    -e CLASH_HTTP_PORT=7890 \
    -e CLASH_SOCKS_PORT=7891 \
    -e CLASH_TPROXY_PORT=7892 \
    -e CLASH_MIXED_PORT=7893 \
    -e DASH_PORT=8080 \
    -e UDP_PROXY=1 \
    -v /path/to/etc/clash:/etc/clash \
    chisbread/chislash:latest
```
# 感谢
- https://github.com/Dreamacro/clash
- https://github.com/haishanh/yacd