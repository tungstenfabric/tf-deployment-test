import os
import re
import sys

orchestrator_tag = os.environ.get("ORCHESTRATOR")
deployer_tag = os.environ.get('DEPLOYER')
additional_tags = os.environ.get('DEPLOYMENT_TEST_TAGS', set())
if additional_tags != set():
    additional_tags = set(additional_tags.split(','))


for line in sys.stdin:
    # get tags for every test
    try:
        test_tags = re.search('\[(.*)\]', line).group(1)
    except:
        continue
    test_tags_list = test_tags.split(',')

    # filter for orchestrator
    if orchestrator_tag in test_tags_list:
        test_tags_list.remove(orchestrator_tag)
    elif 'all-orchestrators' in test_tags_list:
        test_tags_list.remove('all-orchestrators')
    else:
        continue

    # filter for deployer
    if deployer_tag in test_tags_list:
        test_tags_list.remove(deployer_tag)
    elif 'all-deployers' in test_tags_list:
        test_tags_list.remove('all-deployers')
    else:
        continue

    # filter for additional
    if additional_tags == set (test_tags_list):
        print(line.strip('\n'))
