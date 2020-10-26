#!/usr/bin/env python3
import sys
import yaml
import json


def apply_defaults_from_instances_yaml(instances_yaml):
    with open(instances_yaml) as file:
        instances_yaml_json = yaml.safe_load(file)
        dict_contrail_configuration = instances_yaml_json["contrail_configuration"]
        apply_defaults_value = dict_contrail_configuration.get("APPLY_DEFAULTS", "true")
        return apply_defaults_value


# expected instances_yaml_file = '/instances.yaml'
instances_yaml_file = sys.argv[1]
apply_defaults = apply_defaults_from_instances_yaml(instances_yaml_file)
print(apply_defaults)
