ARG LINUX_DISTR=centos
ARG LINUX_DISTR_VER=7
FROM $LINUX_DISTR:$LINUX_DISTR_VER

COPY licensing.txt /licenses
COPY *.sh requirements.txt /
COPY .testr.conf deployment_test.py /tf-deployment-test/
COPY bash_tests /tf-deployment-test/bash_tests
COPY my_fixtures /tf-deployment-test/my_fixtures
COPY rhosp /tf-deployment-test/rhosp
COPY scripts /tf-deployment-test/scripts

RUN yum install -y python3 && \
    yum clean all -y && \
    rm -rf /var/cache/yum

RUN pip3 install --upgrade --no-compile pip && \
    pip3 install --no-compile -r /requirements.txt

ENTRYPOINT ["/entrypoint.sh"]
