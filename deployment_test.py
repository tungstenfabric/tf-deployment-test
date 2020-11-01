import testtools
from vnc_api import vnc_api
import os
from vnc_api.vnc_api import EncapsulationPrioritiesType
import paramiko
from paramiko.ssh_exception import SSHException
import stat
import yaml


class BaseTestCase(testtools.TestCase):
    def setUp(self):
        # self.host_fixture = self.useFixture(HostFixture())
        self.workspace_path = os.getenv('WORKSPACE')
        super(BaseTestCase, self).setUp()

    def check_cmd_on_host(self, cmd):
        (exec_res, stdout, stderr) = self.host_fixture.exec_on_host(cmd)
        output_text = ""
        for line in stdout.readlines():
            self.logger.info("%s " % line)
            output_text += f"{line}\n"
        for line in stderr.readlines():
            self.logger.info("bash.stderr: %s " % line)
        try:
            if (exec_res is not True) and (int(exec_res) > 0):
                exec_res = False
        except:
            pass
        self.assertFalse(exec_res)
        return output_text

    def run_bash_test_on_host(self, bash_file_name):
        remote_path = os.path.join("/tmp/tf-deployment-test", bash_file_name)
        self.check_cmd_on_host(remote_path)

    def get_encap_priority(self, my_hostname):
        # TODO: add supproting SSL
        # my_fq_name type list
        my_fq_name = ['default-global-system-config', 'default-global-vrouter-config']
        vnc_lib = vnc_api.VncApi(api_server_host=my_hostname)
        gr_obj = vnc_lib.global_vrouter_config_read(fq_name=my_fq_name)
        encap_priority = gr_obj.get_encapsulation_priorities()
        self.logger.info(f"get encap_priority src: {encap_priority}")
        res = str(encap_priority)[17:-1].replace("'", "").replace(" ", "")
        return res
        # before "encapsulation = ['MPLSoUDP', 'MPLSoGRE', 'VXLAN']"
        # after "MPLSoUDP,MPLSoGRE,VXLAN"

    def set_encap_priority(self, encaps, hostname):
        # TODO: add supproting SSL
        self.logger.info(f"we begining set encap_priority = {new_encap_priority}")
        new_encap = encaps.split(",")
        fq_name = ['default-global-system-config', 'default-global-vrouter-config']
        vnc_lib = vnc_api.VncApi(api_server_host=hostname)
        gr_obj = vnc_lib.global_vrouter_config_read(fq_name=fq_name)
        encap_obj = EncapsulationPrioritiesType(encapsulation=new_encap)
        gr_obj.set_encapsulation_priorities(encap_obj)
        vnc_lib.global_vrouter_config_update(gr_obj)

    def get_array_controller_nodes(self):
        controller_nodes = os.environ["CONTROLLER_NODES"]
        array_controller_nodes = controller_nodes.replace(",", " ").split()
        return array_controller_nodes

    def get_master_node(self):
        array_controller_nodes = self.get_array_controller_nodes()
        master_node = array_controller_nodes[0]
        return master_node

    def apply_defaults_from_instances_yaml(self, instances_yaml):
        instances_yaml_json = yaml.safe_load(instances_yaml)
        dict_contrail_configuration = instances_yaml_json["contrail_configuration"]
        apply_defaults_value = dict_contrail_configuration.get("APPLY_DEFAULTS", "true")
        return apply_defaults_value

    def get_apply_defaults_value_from_instances_yaml(self, master_node, instances_yaml_file):
        self.create_ssh_connection(master_node)
        instances_yaml = self.check_cmd_on_node_by_ssh(f"cat {instances_yaml_file}")
        self.close_ssh_connection()
        apply_defaults = self.apply_defaults_from_instances_yaml(instances_yaml)
        self.logger.info(f'apply_defaults is {apply_defaults}')

    def get_apply_defaults_value_from_env(self):
        apply_defaults_value = os.getenv("APPLY_DEFAULTS", "true")
        self.logger.info(f'apply_defaults is {apply_defaults_value}')
        return apply_defaults_value

    def reboot_containers_without_our_container_by_name(self, node, cont_name):
        # cont_name = "tf-deployment-test-apply"
        self.create_ssh_connection(node)
        test_container_id = self.check_cmd_on_node_by_ssh(f'sudo docker ps -q -f name={cont_name}').strip()
        if test_container_id == "":
            reboot_command = "sudo docker restart $(sudo docker ps -q &>/dev/null"
        else:
            reboot_command = f"sudo docker restart $(sudo docker ps -q | grep -v {test_container_id}) &>/dev/null"
        self.check_cmd_on_node_by_ssh("sudo docker ps")
        self.logger.info(f'Before reboot: {datetime.datetime.now()}')
        self.check_cmd_on_node_by_ssh(reboot_command)
        time.sleep(60)
        self.logger.info(f'After reboot: {datetime.datetime.now()}')
        self.check_cmd_on_node_by_ssh("sudo docker ps")
        self.close_ssh_connection()
        return test_container_id

    def reboot_containers(self, instances_yaml):
        instances_yaml_json = yaml.safe_load(instances_yaml)
        dict_contrail_configuration = instances_yaml_json["contrail_configuration"]
        apply_defaults_value = dict_contrail_configuration.get("APPLY_DEFAULTS", "true")
        return apply_defaults_value

    def assert_with_logs(self, assert_logic, assert_message):
        if assert_logic is False:
            self.logger.info(f'assert false: {assert_message}')
        assert assert_logic

    # ----------------------------------------------------------------------------
    # For Debug:

    def run_cmd_here(self, cmd):

        def run_shell_command(cmd_str):
            """Run a Linux shell command and return the result code."""
            # import logging
            from subprocess import Popen, STDOUT, PIPE
            fail_text = ""
            p = Popen(cmd_str,
                      shell=True,
                      stderr=STDOUT,
                      stdout=PIPE,
                      bufsize=1,
                      universal_newlines=True)
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

        self.logger.info("-"*20)
        self.logger.info(f"vipolnim:, {cmd}")
        res_code, cmd_output, fail_msg = run_shell_command(cmd)
        self.logger.info(f"res_code: {res_code}")
        if res_code != 0 and fail_msg != "":
            self.logger.info(f"fail_msg: {fail_msg}")
            exit(-1)
        self.logger.info(f"return here:\n{cmd_output}".strip())
        self.logger.info("="*20)

        return cmd_output
    # END def run_cmd_here
# -------------------------------------------------------

    def check_cmd_on_node_by_ssh(self, cmd):
        (exec_res, stdout, stderr) = self.exec_on_ssh(cmd)
        output_text = ""
        self.logger.info("-"*20)
        self.logger.info(f"vipolnim na ssh: {cmd}")
        for line in stdout.readlines():
            # self.logger.info("%s " % line)
            output_text += f"{line}\n"
        for line in stderr.readlines():
            self.logger.info("bash.stderr: %s " % line)
        try:
            if (exec_res is not True) and (int(exec_res) > 0):
                exec_res = False
        except:
            pass
        self.assertFalse(exec_res)
        self.logger.info(f"res_code: {exec_res}")
        self.logger.info(f"return ssh:\n{output_text}".strip())
        self.logger.info("="*20)
        return output_text

    def create_ssh_connection(self, node):
        host_user = os.getenv("TF_HOST_USER")
        host_key = os.getenv("TF_SSH_KEY")
        host = node
        ssh_file = os.path.expanduser('pk.key')
        with open(ssh_file, 'w') as fd:
            fd.write(host_key)
        os.chmod(ssh_file, stat.S_IRWXU)
        rsync_cmd = "rsync -Pav -e \"ssh -i %s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no\" /tf-deployment-test %s@%s:/tmp/" % (ssh_file, host_user, host)
        code = os.system(rsync_cmd)
        if code:
            raise Exception(f"ERROR: rsync tests to node {node} fails with code {code} ")
        if not host_user or not host_key or not host:
            raise Exception(f"ERROR: Need to pass node {node} credentials to run the tests")
        self._client = paramiko.SSHClient()
        self._client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.logger.info(f"create ssh connection with node {node}")
        self._client.connect(host, username=host_user, key_filename=ssh_file, timeout=5)
        # self.addCleanup(delattr, self, 'host_user')
        # self.addCleanup(delattr, self, 'host_key')
        # self.addCleanup(delattr, self, 'host')
        # self.addCleanup(self._client.close)

    def exec_on_ssh(self, command):
        if not self._client:
            raise Exception("ERROR: connection has not been set up yet")
        exec_res = 0
        chan = self._client.get_transport().open_session()
        stdout = chan.makefile()
        stderr = chan.makefile_stderr()
        try:
            chan.exec_command(command)
            exec_res = chan.recv_exit_status()
        except SSHException:
            exec_res = 1
        return (exec_res, stdout, stderr)

    def close_ssh_connection(self):
        self._client.close()
        self.logger.info(f"ssh was disconnected")

# ----------------------------------------------------------------------------------
    def add_to_log(self, text_info):
        self.logger.info(f"add to log: {text_info}")
