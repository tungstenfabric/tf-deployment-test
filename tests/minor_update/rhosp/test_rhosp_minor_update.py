import os

from testtools.testcase import attr
from common.deployment_test_case import DeploymentTestCase


class RhospMinorUpdateTests(DeploymentTestCase):
    @attr("rhosp", "openstack", "minor_update")
    def test_rhosp_update(self):
        self.run_test_remotely('tests/update/rhosp/rhosp_minor_update.sh')
        self.check_container_tags(os.getenv("CONTRAIL_CONTAINER_TAG_ORIGINAL"))
