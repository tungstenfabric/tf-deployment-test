FROM centos:7
COPY ./*.sh /

COPY requirements.txt .
# install most packages from pypi and only then python-Fabric
RUN yum install -y sudo python3 && \
    pip3 install --no-cache-dir -r requirements.txt

COPY apply_defaults_tests /apply_defaults_tests/

RUN echo "ls -la /apply_defaults_tests/*" \
    ls -la /apply_defaults_tests/*

# CMD ["/usr/bin/tail","-f","/dev/null"]

ENTRYPOINT ["/entrypoint.sh"]
