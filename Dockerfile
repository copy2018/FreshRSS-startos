FROM louislam/uptime-kuma:1.23.16-alpine

ADD ./docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
