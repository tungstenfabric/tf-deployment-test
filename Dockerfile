FROM centos:7
COPY . /*.sh
ENTRYPOINT ["/entrypoint.sh"]
