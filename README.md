# chislash
- 开箱即用的clash镜像

# 使用
```bash
sudo docker run --privileged --network="host" --name chislash --restart unless-stopped -d \
    -e DASH_PORT=8080 \
    -e CLASH_HTTP_PORT=7890 \
    -e CLASH_SOCKS_PORT=7891 \
    -e CLASH_REDIR_PORT=7892 \
    -e CLASH_MIXED_PORT=7893 \
    -v /path/to/etc/clash:/etc/clash \
    chisbread/chislash:latest
```
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
      - CLASH_REDIR_PORT=7892
      - CLASH_MIXED_PORT=7893
      - DASH_PORT=8080
    volumes:
      - <path to config>:/etc/clash
    network_mode: "host"
    restart: unless-stopped
```
# 感谢
- https://github.com/Dreamacro/clash
- https://github.com/haishanh/yacd