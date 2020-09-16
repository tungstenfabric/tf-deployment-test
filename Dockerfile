FROM centos:7
COPY . /
ENTRYPOINT ["/entrypoint.sh"]
