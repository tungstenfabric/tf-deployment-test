FROM centos:7
COPY ./ /

# need files on node in "./.ssh" directory
COPY ./.ssh /etc/ssh/sshd_config
COPY ./.ssh /root/.ssh/

# install most packages from pypi and only then python-Fabric
RUN yum install -y sudo python3 openssh-clients && \
    python3 -m pip install --no-compile "contrail-api-client==2005" "future==0.18.2" "six==1.15.0" "requests==2.24.0" "PyYAML==5.3.1"

ENTRYPOINT ["/entrypoint.sh"]