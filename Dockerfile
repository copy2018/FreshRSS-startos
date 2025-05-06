FROM freshrss/freshrss:1.26.2

ADD ./docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker_entrypoint.sh"]
