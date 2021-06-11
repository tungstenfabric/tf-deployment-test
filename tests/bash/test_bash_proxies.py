import os
from testtools.testcase import attr
from testtools import skipIf
from common.deployment_test_case import DeploymentTestCase


class BashTests(DeploymentTestCase):
    # k8s_manifests-kubernetes attr means deployer is k8s_manifests
    # and orchestrator  is kubernetes
    # this test will be run for k8s_manifests deployer and kubernetes orchestrator
    @attr("k8s_manifests", "kubernetes")
    def test_check_agent_status(self):
        self.run_test_remotely('tests/bash/check_agent_status.sh')

    @attr("juju", "hybrid")
    def test_k8s_keystone_auth(self):
        self.run_test_remotely('tests/bash/k8s_keystone_auth.sh')

    @skipIf(os.getenv("ENABLE_NAGIOS", 'false').lower() != 'true', "Skipped as nrpe isn't enabled")
    @attr("juju", "all-orchestrators")
    def test_juju_nrpe(self):
        self.run_test_remotely('tests/bash/juju_nrpe.sh')

    @attr("all-deployers", "kubernetes")
    def test_simple_ping(self):
        self.run_test_remotely('tests/bash/simple_ping.sh')
