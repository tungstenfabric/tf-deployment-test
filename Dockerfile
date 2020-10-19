FROM centos:7
COPY ./ /tf-deployment-test
RUN yum install -y python3 && python3 -m venv /env && source /env/bin/activate && pip install --upgrade pip && pip install -r /tf-deployment-test/requirements.txt

ENTRYPOINT ["/tf-deployment-test/entrypoint.sh"]
