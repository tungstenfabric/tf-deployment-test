from deployment_test import BaseTestCase
import paramiko
import os
from paramiko.ssh_exception import SSHException
import stat
import yaml
import datetime
import time

# need move to BaseTestCase:
# run_cmd_in_container(cmd), open_ssh_connection(node), close_ssh_connection
# exec_on_host(command) need upgrade to check_cmd_on_node_by_ssh(cmd)

class TestApplyDefaultsCases(BaseTestCase):

    @staticmethod
    def get_array_controller_nodes():
        controller_nodes = os.environ["CONTROLLER_NODES"]
        array_controller_nodes = controller_nodes.replace(",", " ").split()
        return array_controller_nodes

    def get_master_node(self):
        array_controller_nodes = self.get_array_controller_nodes()
        master_node = array_controller_nodes[0]
        self.logger.info(f'master_node is {master_node}')
        return master_node

    def get_apply_defaults_value_from_env(self):
        apply_defaults_value = os.getenv("APPLY_DEFAULTS", "true")
        self.logger.info(f'apply_defaults is {apply_defaults_value}')
        return apply_defaults_value
