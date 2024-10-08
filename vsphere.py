import kopf
import requests
import subprocess
import json
from kubernetes import client, config
import logging
import os

logging.basicConfig(level=logging.INFO)

# logging.info("This is an info message")
# logging.warning("This is a warning message")
# logging.error("This is an error message")

# Load the Kubernetes configuration
config.load_incluster_config()

# Helper function to create vsphere
def create_vsphere(metadata, spec, kind):
    folder='/nested-vsphere'
    a_dict = {}
    a_dict['metadata'] = metadata
    a_dict['spec'] = spec
    a_dict['kind'] = kind
    a_dict['operation'] = "apply"
    json_file='/root/{0}_from_kube.json'.format(a_dict['metadata']['name'])
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    result=subprocess.Popen(['/bin/bash', 'apply.sh', json_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    if os.path.isfile("/root/govc.error"):
      logging.error("create_vsphere: External vCenter not reachable")
      raise ValueError("create_vsphere: External vCenter not reachable")


# Helper function to delete vsphere
def delete_vsphere(metadata, spec, kind):
    folder='/nested-vsphere'
    a_dict = {}
    a_dict['metadata'] = metadata
    a_dict['spec'] = spec
    a_dict['kind'] = kind
    a_dict['operation'] = "destroy"
    json_file='/root/{0}_from_kube.json'.format(a_dict['metadata']['name'])
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    result=subprocess.Popen(['/bin/bash', 'apply.sh', json_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    if os.path.isfile("/root/govc.error"):
      logging.error("delete_vsphere: External vCenter not reachable")
      raise ValueError("delete_vsphere: External vCenter not reachable")
#
#
#
#
@kopf.on.create('vsphere')
def on_create(body, **kwargs):
    metadata = body['metadata']
    spec = body['spec']
    kind = body['kind']
    try:
        create_vsphere(metadata, spec, kind)
    except requests.RequestException as e:
        raise kopf.PermanentError(f'Failed to create external resource: {e}')

@kopf.on.delete('vsphere')
def on_delete(body, **kwargs):
    metadata = body['metadata']
    spec = body['spec']
    kind = body['kind']
    try:
        delete_vsphere(metadata, spec, kind)
    except requests.RequestException as e:
        raise kopf.PermanentError(f'Failed to delete external resource: {e}')

@kopf.on.create('vsphere-avi')
def on_create(body, **kwargs):
    metadata = body['metadata']
    spec = body['spec']
    kind = body['kind']
    try:
        create_vsphere(metadata, spec, kind)
    except requests.RequestException as e:
        raise kopf.PermanentError(f'Failed to create external resource: {e}')

@kopf.on.delete('vsphere-avi')
def on_delete(body, **kwargs):
    metadata = body['metadata']
    spec = body['spec']
    kind = body['kind']
    try:
        delete_vsphere(metadata, spec, kind)
    except requests.RequestException as e:
        raise kopf.PermanentError(f'Failed to delete external resource: {e}')



@kopf.on.create('vsphere-nsx')
def on_create(body, **kwargs):
    metadata = body['metadata']
    spec = body['spec']
    kind = body['kind']
    try:
        create_vsphere(metadata, spec, kind)
    except requests.RequestException as e:
        raise kopf.PermanentError(f'Failed to create external resource: {e}')

@kopf.on.delete('vsphere-nsx')
def on_delete(body, **kwargs):
    metadata = body['metadata']
    spec = body['spec']
    kind = body['kind']
    try:
        delete_vsphere(metadata, spec, kind)
    except requests.RequestException as e:
        raise kopf.PermanentError(f'Failed to delete external resource: {e}')
# #
# @kopf.on.create('nsx-avi')
# def on_create(body, **kwargs):
#     body = body
#     try:
#         create_nsx_avi(body)
#     except requests.RequestException as e:
#         raise kopf.PermanentError(f'Failed to create external resource: {e}')
#
# @kopf.on.delete('nsx-avi')
# def on_delete(body, **kwargs):
#     body = body
#     try:
#         delete_nsx_avi(body)
#     except requests.RequestException as e:
#         raise kopf.PermanentError(f'Failed to delete external resource: {e}')