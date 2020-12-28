from testtools.testcase import attr
from common.deployment_test_case import DeploymentTestCase


class RhospZiuTests(DeploymentTestCase):
    @attr("rhosp", "openstack", "ziu")
    def test_rhosp_ziu(self):
        self.run_test_remotely('tests/ziu/rhosp/rhosp_ziu.sh')
