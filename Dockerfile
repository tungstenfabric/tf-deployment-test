FROM centos:7
COPY . /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
