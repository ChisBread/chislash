FROM ubuntu:20.04
RUN sed -i s@/archive.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list \
    && apt-get clean \
    && apt-get update \
    && apt-get install -y wget xz-utils iproute2 iptables \
        curl python3 python3-yaml kmod \
    && rm -rf /var/lib/apt/lists/* \
    && rm /bin/sh && ln -s /bin/bash /bin/sh \
    && mv -v /usr/sbin/ip6tables /usr/sbin/ip6tables--DISABLED-$(date +"%Y-%m-%d--%H-%M") \
    && cp -v /usr/sbin/ip6tables-nft /usr/sbin/ip6tables \
    && mv -v /usr/sbin/iptables /usr/sbin/iptables--DISABLED-$(date +"%Y-%m-%d--%H-%M") \
    && cp -v /usr/sbin/iptables-nft /usr/sbin/iptables

ARG CLASHVER=v1.10.6
ARG YACDVER=v0.3.4
ARG SCVER=v0.7.2
RUN echo 'detect arch ...' \
    && SC_ARCH='unknown' && ARCH='unknown' \
    && if [[ `uname -p` =~ "x86_64" ]]; then ARCH='amd64'; SC_ARCH='linux64'; fi \
    && if [[ `uname -p` =~ "armv7" ]]; then \
        ARCH='armv7'; SC_ARCH='armv7'; \
        for i in /etc/ssl/certs/*.pem; do HASH=$(openssl x509 -hash -noout -in $i); ln -s $(basename $i) /etc/ssl/certs/$HASH.0; done \
    fi \
    && if [[ `uname -p` =~ "aarch64" ]]; then ARCH='armv8';SC_ARCH='aarch64'; fi \
    && echo 'install clash ...' \
    && wget https://github.com/Dreamacro/clash/releases/download/$CLASHVER/clash-linux-$ARCH-$CLASHVER.gz \
    && gunzip clash-linux-$ARCH-$CLASHVER.gz \
    && mv clash-linux-$ARCH-$CLASHVER /usr/bin/clash \
    && chmod 774 /usr/bin/clash \
    && echo 'install yacd dashboard ...' \
    && wget https://github.com/haishanh/yacd/releases/download/$YACDVER/yacd.tar.xz \
    && mkdir -p /default/clash/dashboard \
    && tar xvf yacd.tar.xz -C /default/clash/dashboard && rm yacd.tar.xz \
    && echo 'download default Country.mmdb ...' \
    && wget https://geolite.clash.dev/Country.mmdb -O /default/clash/Country.mmdb \
    && echo 'install subconverter ...' \
    && wget https://github.com/tindy2013/subconverter/releases/download/$SCVER/subconverter_$SC_ARCH.tar.gz \
    && gunzip subconverter_$SC_ARCH.tar.gz && tar xvf subconverter_$SC_ARCH.tar && rm subconverter_$SC_ARCH.tar \
    && mv subconverter /default/ \
    && wget https://github.com/ACL4SSR/ACL4SSR/archive/refs/heads/master.tar.gz \
    && gunzip master.tar.gz && tar xvf master.tar && rm master.tar \
    && mkdir /default/exports && mv ACL4SSR-master /default/exports/ACL4SSR \
    && chmod -R a+r /default/
    
ENV ENABLE_CLASH=1
ENV REQUIRED_CONFIG=""
ENV CLASH_HTTP_PORT=7890
ENV CLASH_SOCKS_PORT=7891
ENV CLASH_TPROXY_PORT=7892
ENV CLASH_MIXED_PORT=7893
ENV DASH_PORT=8080
ENV DASH_PATH="/etc/clash/dashboard/public"
ENV IP_ROUTE=1
ENV UDP_PROXY=1
ENV IPV6_PROXY=1
ENV PROXY_FWMARK=0x162
ENV PROXY_ROUTE_TABLE=0x162
ENV LOG_LEVEL="info"
ENV SECRET=""
ENV ENABLE_SUBCONV=1
ENV SUBCONV_URL="http://127.0.0.1:25500/sub"
ENV SUBSCR_URLS=""
ENV SUBSCR_EXPR=6000
ENV REMOTE_CONV_RULE="http://127.0.0.1:8091/ACL4SSR/Clash/config/ACL4SSR_Online_Full.ini"
ENV EXPORT_DIR_PORT=8091
ENV EXPORT_DIR_BIND='0.0.0.0'
ENV NO_ENGLISH=true

EXPOSE $CLASH_HTTP_PORT $CLASH_SOCKS_PORT $CLASH_TPROXY_PORT $CLASH_MIXED_PORT $DASH_PORT $SUBCONV_PORT
VOLUME /etc/clash
COPY start.sh /
COPY transparent_proxy /transparent_proxy
COPY utils /default/clash/utils
RUN chmod +x /transparent_proxy/*
RUN useradd -g root -s /bin/bash -u 1086 -m clash
ENTRYPOINT [ "/start.sh" ]
