# chislash
- 开箱即用的clash镜像

# 使用
```bash
sudo docker run --name chislash --restart unless-stopped -d \
    -e DASH_PORT=8080 \
    -p 7890:7890 \
    -p 7891:7891 \
    -p 7892:7892 \
    -p 8080:8080 \
    -v /path/to/etc/clash:/etc/clash \
    chisbread/chislash:latest
```
```yaml
version: "0.1"
services:
  chislash:
    image: chisbread/chislash
    container_name: chislash
    environment:
      - TZ=Asia/Shanghai
      - CLASH_MIXED_PORT=7890
      - CLASH_SOCKS_PORT=7891
      - CLASH_HTTP_PORT=7892
      - DASH_PORT=8080
    volumes:
      - <path to config>:/etc/clash
    ports:
      - 7890:7890
      - 7891:7891
      - 7892:7892
      - 8080:8080
    restart: unless-stopped
```
# 感谢
- https://github.com/Dreamacro/clash
- https://github.com/haishanh/yacd