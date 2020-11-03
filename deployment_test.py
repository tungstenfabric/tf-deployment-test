import testtools
from my_fixtures import HostFixture
import os
import time


class BaseTestCase(testtools.TestCase):
    def setUp(self):
        self.workspace_path = os.getenv('WORKSPACE')
        super(BaseTestCase, self).setUp()

    def check_cmd_on_host(self, cmd):
        host_fixture = self.useFixture(HostFixture())
        (exec_res, stdout, stderr) = host_fixture.exec_on_host(cmd)
        for line in stdout.readlines():
            self.logger.info("%s " % line)
        for line in stderr.readlines():
            self.logger.info("bash.stderr: %s " % line)
        self.assertFalse(exec_res)

    def run_bash_test_on_host(self, bash_file_name):
        remote_path = os.path.join("/tmp/tf-deployment-test", bash_file_name)
        self.check_cmd_on_host(remote_path)

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

    def restart_containers_without_our_container_by_name(self, cont_name):
        # TODO: reboot only contrail containers
        # but now we reboot all another containers
        array_controller_nodes = self.get_array_controller_nodes()
        for node in array_controller_nodes:
            host_fixture = self.useFixture(HostFixture(hostname=node))
            test_container_id = host_fixture.check_cmd_on_node_by_ssh(f'sudo docker ps -q -f name={cont_name}').strip()
            if test_container_id == "":
                reboot_command = "sudo docker restart $(sudo docker ps -q) &>/dev/null"
            else:
                self.logger.info(f'on node {node}: our_container_id = _{test_container_id}_')
                reboot_command = f"sudo docker restart $(sudo docker ps -q | grep -v {test_container_id}) &>/dev/null"
            self.logger.info(f'Begin restarting containers on node {node} in {datetime.datetime.now()}')
            host_fixture.check_cmd_on_node_by_ssh(reboot_command)
            time.sleep(60)
            self.logger.info(f'Finished restart on node {node} in {datetime.datetime.now()}')

    def run_cmd_here(self, cmd):

        def run_shell_command(cmd_str):
            """Run a Linux shell command and return the result code."""
            fail_text = ""
            os.system(cmd_str)
            output_lines = []
            while True:
                output = p.stdout.readline().strip()
                if len(output) == 0 and p.poll() is not None:
                    break
                output_lines.append(output)
            cmd_code = p.returncode
            cmd_stdout = "\n".join(output_lines)
            return cmd_code, cmd_stdout, fail_text
        # END def run_shell_command

        self.logger.info("-" * 20)
        self.logger.info(f"shell in containers: {cmd}")
        res_code, cmd_output, fail_msg = run_shell_command(cmd)
        self.logger.info(f"res_code: {res_code}")
        if res_code != 0 and fail_msg != "":
            self.logger.info(f"fail_msg: {fail_msg}")
            exit(-1)
        self.logger.info(f"return container:\n{cmd_output}".strip())
        self.logger.info("=" * 20)
        return cmd_output
    # END def run_cmd_here
