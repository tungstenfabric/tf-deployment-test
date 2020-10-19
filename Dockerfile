ARG LINUX_DISTR=centos
ARG LINUX_DISTR_VER=7
FROM $LINUX_DISTR:$LINUX_DISTR_VER

RUN mkdir /licenses /tf-deployment-test
COPY licensing.txt /licenses

COPY *.sh requirements.txt /

COPY .testr.conf bash_tests my_fixtures rhosp scripts deployment_test.py /tf-deployment-test/

RUN yum install -y python3 && \
    yum clean all -y && \
    rm -rf /var/cache/yum

RUN pip3 install --upgrade pip --no-compile && \
    pip3 install --no-compile -r /tf-deployment-test/requirements.txt

ENTRYPOINT ["/entrypoint.sh"]
