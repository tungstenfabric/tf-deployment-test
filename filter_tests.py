import re

input_filename = '/tmp/test_list'
output_filename = '/tmp/test_list_filtered'

input_file = open(input_filename, 'r')
output_file = open(output_filename, 'w')

def get_tags(quality):
    for line in input_file:
        if quality in line:
            return list(line.split('='))[1].strip('\n')


orchestrator_tag = get_tags('ORCHESTRATOR_TAG')
deployer_tag = get_tags('DEPLOYER_TAG')
additional_tags = list(get_tags('DEPLOYMENT_TEST_TAGS').split(','))
if additional_tags == ['']:
    additional_tags = []

for line in input_file:
    # skip lines with searched tags
    if '_TAG' in line:
        continue

    # get tags for every test
    try:
        test_tags = re.search('\[(.*)\]', line).group(1)
    except:
        continue
    test_tags_list = list(test_tags.split(','))

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
    if set(additional_tags) == set (test_tags_list):
        output_file.write(line)

input_file.close()
output_file.close()
