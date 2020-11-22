import os
import sys
import yaml

tag = os.environ["CONTRAIL_CONTAINER_TAG"]
registry = os.environ["CONTAINER_REGISTRY"]

source = sys.stdin.read()
instances = yaml.load(source, Loader=yaml.Loader)

instances["contrail_configuration"]["CONTRAIL_CONTAINER_TAG"] = tag
instances["global_configuration"]["CONTAINER_REGISTRY"] = registry

print(yaml.dump(instances))
