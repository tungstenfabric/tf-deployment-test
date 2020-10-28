import testtools
from my_fixtures import HostFixture
from vnc_api import vnc_api
import os

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
        res = str(encap_priority)[17:-1].replace("'", "").replace(" ", "")
        return res
        # before "encapsulation = ['MPLSoUDP', 'MPLSoGRE', 'VXLAN']"
        # after "MPLSoUDP,MPLSoGRE,VXLAN"

    def get_master_node(self, controller_nodes):
        return controller_nodes.replace(",", " ").split()[0]

# ----------------------------------------------------------------------------
    # For Debug:

    def run_cmd_here(self, cmd):

        def run_shell_command(cmd_str, print_stdout=True, fail_msg=""):
            """Run a Linux shell command and return the result code."""
            import logging
            from subprocess import Popen, STDOUT, PIPE

            p = Popen(cmd_str,
                      shell=True,
                      stderr=STDOUT,
                      stdout=PIPE,
                      bufsize=1,
                      universal_newlines=True)
            logger = logging.getLogger()
            output_lines = []
            while True:
                output = p.stdout.readline().strip()
                if len(output) == 0 and p.poll() is not None:
                    break
                output_lines.append(output)
                #if print_stdout:
                    #logger.info("[cmd] " + output)
            cmd_code = p.returncode
            cmd_stdout = "\n".join(output_lines)
            if cmd_code != 0 and fail_msg != "":
                logger.error(fail_msg)
                exit(-1)
            return cmd_code, cmd_stdout
        # END def run_shell_command

        self.logger.info("-"*20)
        self.logger.info(f"vipolnim:, {cmd}")
        res_code, cmd_output = run_shell_command(cmd)
        self.logger.info(f"res_code: {res_code}")
        self.logger.info(f"cmd_output: {cmd_output}")
        self.logger.info("="*20)

        return cmd_output
    # END def run_cmd_here
