ARG LINUX_DISTR=centos
ARG LINUX_DISTR_VER=7
FROM $LINUX_DISTR:$LINUX_DISTR_VER

COPY . /tf-deployment-test

RUN cp /tf-deployment-test/testrunner.sh / && \
    yum install -y python3 rsync openssh-clients && \
    pip3 install --upgrade --no-compile pip && \
    pip3 install --no-compile -r /tf-deployment-test/requirements.txt && \
    yum clean all -y && \
    rm -rf /var/cache/yum

ENTRYPOINT ["/tf-deployment-test/entrypoint.sh"]
