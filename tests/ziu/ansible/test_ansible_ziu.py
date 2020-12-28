from testtools.testcase import attr
from common.deployment_test_case import DeploymentTestCase


class AnsibleZiuTests(DeploymentTestCase):
    @attr("ansible", "openstack", "ziu")
    def test_ansible_ziu(self):
        self.run_test_remotely('tests/ziu/ansible/ansible_ziu.sh')
