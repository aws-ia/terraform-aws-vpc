# Generates a moved block to remap from singular private subnets to allow for multiple private subnets

import os
import boto3
import argparse
from jinja2 import Template
from ruamel.yaml import YAML
yaml=YAML()

default_client = boto3.client('ec2')

def get_azs(client):
    return [az['ZoneName'] for az in client.describe_availability_zones()['AvailabilityZones']]

def generate_tf(azs):
    with open('moved.tf.j2', 'r') as f:
        try:
            j2_modules_template = Template(f.read())
        except:
            print('Could not load template.')

    moved_file = j2_modules_template.render({'azs':azs})

    with open('../moved.tf', 'w') as o:
        o.write(moved_file)


if __name__ == "__main__":
    regions = [ r['RegionName'] for r in default_client.describe_regions()['Regions'] ]
    regional_clients = { region : boto3.client('ec2', region_name=region) for region in regions }
    all_azs = []
    for _, client in regional_clients.items():
        all_azs.extend(get_azs(client))

    generate_tf(all_azs)
