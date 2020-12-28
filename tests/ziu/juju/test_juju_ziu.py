from testtools.testcase import attr
from common.deployment_test_case import DeploymentTestCase


class JujuZiuTests(DeploymentTestCase):
    @attr("juju", "openstack", "ziu")
    def test_juju_ziu(self):
        self.run_test_remotely('tests/ziu/juju/juju_ziu.sh')
