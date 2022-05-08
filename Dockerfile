FROM ubuntu:20.04
RUN sed -i s@/archive.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list \
    && apt-get clean \
    && apt-get update \
    && apt-get install -y wget xz-utils iproute2 iptables python3 python3-yaml \
    && rm -rf /var/lib/apt/lists/*
ARG ARCH=amd64
ARG CLASHVER=v1.10.6
RUN wget https://github.com/Dreamacro/clash/releases/download/$CLASHVER/clash-linux-$ARCH-$CLASHVER.gz \
    && gunzip clash-linux-$ARCH-$CLASHVER.gz \
    && mv clash-linux-$ARCH-$CLASHVER /usr/bin/clash \
    && chmod 774 /usr/bin/clash
ARG YACDVER=v0.3.4
RUN wget https://github.com/haishanh/yacd/releases/download/$YACDVER/yacd.tar.xz \
    && mkdir -p /default/clash/dashboard \
    && tar xvf yacd.tar.xz -C /default/clash/dashboard \
    && wget https://geolite.clash.dev/Country.mmdb -O /default/clash/Country.mmdb \
    && chmod -R a+r /default/clash
ENV MUST_CONFIG=""
ENV CLASH_HTTP_PORT=7890
ENV CLASH_SOCKS_PORT=7891
ENV CLASH_TPROXY_PORT=7892
ENV CLASH_MIXED_PORT=7893
ENV DASH_PORT=8080
ENV IP_ROUTE=1
ENV UDP_PROXY=1
ENV LOG_LEVEL="info"
ENV SECRET=""
EXPOSE $CLASH_HTTP_PORT $CLASH_SOCKS_PORT $CLASH_TPROXY_PORT $CLASH_MIXED_PORT $DASH_PORT
VOLUME /etc/clash
COPY *.sh /
COPY utils /default/clash/utils
RUN chmod +x /*.sh
RUN useradd -g root -s /bin/bash -u 1086 -m clash && setcap 'cap_net_admin,cap_net_bind_service,cap_net_raw=+ep' /usr/bin/clash
ENTRYPOINT [ "/start.sh" ]