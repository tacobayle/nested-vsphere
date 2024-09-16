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
def create_vsphere(body):
    folder='/nested-vsphere'
    a_dict = body
    a_dict['operation'] = "apply"
    json_file='/root/${0}.json'.format(a_dict['metadata']['name'])
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    result=subprocess.Popen(['/bin/bash', 'apply.sh', json_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    if os.path.isfile("/root/govc.error"):
      logging.error("create_vsphere: External vCenter not reachable")
      raise ValueError("create_vsphere: External vCenter not reachable")


# Helper function to delete vsphere
def delete_vsphere(body):
    folder='/nested-vsphere'
    a_dict = body
    a_dict['operation'] = "destroy"
    json_file='/root/${0}.json'.format(a_dict['metadata']['name'])
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
    body = body
    try:
        create_vsphere(body)
    except requests.RequestException as e:
        raise kopf.PermanentError(f'Failed to create external resource: {e}')

@kopf.on.delete('vsphere')
def on_delete(body, **kwargs):
    body = body
    try:
        delete_vsphere(body)
    except requests.RequestException as e:
        raise kopf.PermanentError(f'Failed to delete external resource: {e}')
#
# @kopf.on.create('nsx')
# def on_create(body, **kwargs):
#     body = body
#     try:
#         create_nsx(body)
#     except requests.RequestException as e:
#         raise kopf.PermanentError(f'Failed to create external resource: {e}')
#
# @kopf.on.delete('nsx')
# def on_delete(body, **kwargs):
#     body = body
#     try:
#         delete_nsx(body)
#     except requests.RequestException as e:
#         raise kopf.PermanentError(f'Failed to delete external resource: {e}')
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