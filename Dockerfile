FROM alpine:3.18

RUN apk add --no-cache \
  openssh \
  wireguard-tools-wg-quick \
  sudo
RUN \
  echo "**** install dependencies ****" && \
  apk add --no-cache --virtual=build-dependencies \
    build-base \
    elfutils-dev \
    gcc \
    git \
    jq \
    curl \
    linux-headers && \
  apk add --no-cache \
    bc \
    coredns \
    gnupg \
    grep \
    iproute2 \
    iptables \
    ip6tables \
    iputils \
    libcap-utils \
    libqrencode \
    net-tools \
    openresolv \
    perl && \
  echo "wireguard" >> /etc/modules && \
  echo "**** install wireguard-tools ****" && \
  if [ -z ${WIREGUARD_RELEASE+x} ]; then \
    WIREGUARD_RELEASE=$(curl -sX GET "https://api.github.com/repos/WireGuard/wireguard-tools/tags" \
    | jq -r .[0].name); \
  fi && \
  git clone https://git.zx2c4.com/wireguard-tools && \
  cd wireguard-tools && \
  git checkout "${WIREGUARD_RELEASE}" && \
  sed -i 's|\[\[ $proto == -4 \]\] && cmd sysctl -q net\.ipv4\.conf\.all\.src_valid_mark=1|[[ $proto == -4 ]] \&\& [[ $(sysctl -n net.ipv4.conf.all.src_valid_mark) != 1 ]] \&\& cmd sysctl -q net.ipv4.conf.all.src_valid_mark=1|' src/wg-quick/linux.bash && \
  make -C src -j$(nproc) && \
  make -C src install && \
  echo "**** clean up ****" && \
  apk del --no-network build-dependencies && \
  rm -rf /tmp/* && \
  cd .. && \
  rm -rf wireguard-tools

WORKDIR /workspace
COPY ./scripts/* ./
RUN chmod +x ./*
COPY .bash_profile ./.bash_profile

RUN mkdir -p /workspace/programs && \
    ln -s /usr/bin/wg-quick /workspace/programs/ && \
    ln -s /usr/bin/wg /workspace/programs/ && \
    # Remove the line below!!
    ln -s /usr/bin/sleep /workspace/programs/ && \
    ln -s /usr/bin/ssh /workspace/programs/ && \
    ln -s /usr/bin/scp /workspace/programs/ && \
    ln -s /usr/bin/exit /workspace/programs/ && \
    ln -s /bin/rm /workspace/programs/ && \
    ln -s /bin/cat /workspace/programs/ && \
    ln -s /bin/echo /workspace/programs/
RUN adduser -s /bin/rbash -h /workspace --disabled-password -g 0 1000
RUN echo "wireproxy ALL=(ALL) NOPASSWD: /usr/bin/wg-quick" > /etc/sudoers.d/wireproxy

RUN chattr +i /workspace/.bash_profile && \
    mv /bin/bash /bin/rbash && \
    rm -f /bin/sh

USER 1000
ENTRYPOINT ["/bin/rbash", "create-wg-connection.sh"]