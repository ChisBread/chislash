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
    privileged: true
    image: chisbread/chislash
    container_name: chislash
    environment:
      - TZ=Asia/Shanghai
      - CLASH_HTTP_PORT=7890
      - CLASH_SOCKS_PORT=7891
      - CLASH_TPROXY_PORT=7892
      - CLASH_MIXED_PORT=7893
      - DASH_PORT=8080 # RESTful API端口(同时也是Web UI端口 e.g. http://IP:8080/ui)
      - IP_ROUTE=1 # 开启透明代理 optional (default:1)
      - UDP_PROXY=1 # 开启透明代理-UDP转发(当代理节点不支持UDP时,可关闭) optional (default:1)
    volumes:
      - <path to config>:/etc/clash
    network_mode: "host"
    restart: unless-stopped
```
- docker run
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