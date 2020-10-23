FROM centos:7
COPY ./ /

# install most packages from pypi and only then python-Fabric
RUN yum install -y sudo python3 && \
    python3 -m pip install --no-compile "contrail-api-client==2005" "future==0.18.2" "six==1.15.0" "requests==2.24.0"

ENTRYPOINT ["/entrypoint.sh"]
