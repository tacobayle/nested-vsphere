from flask import Flask
import subprocess
import json
from flask_restful import Api, Resource, reqparse, abort
from flask_cors import CORS

# curl -X POST http://127.0.0.1:5000/api/createlbaas -d '{"vs_name":"demo2", "operation":"apply", "app_profile":"private","count":2, "cert": "self-signed"}' -H "Content-Type: application/json"
# curl -X POST http://127.0.0.1:5000/api/createlbaas -d '{"vs_name":"demo2", "operation":"apply", "app_profile":"public","count":1, "cert": "new-cert"}' -H "Content-Type: application/json"
# curl -X DELETE http://127.0.0.1:5000/api/deletelbaas -d '{"vs_name":"python-vs"}' -H "Content-Type: application/json"
# curl -X DELETE http://127.0.0.1:5000/api/cleanup -H "Content-Type: application/json"
# curl -X POST http://127.0.0.1:5000/api/getapp -H "Content-Type: application/json"
# curl -X POST http://127.0.0.1:5000/api/getsesizing -d '{"vs_name":"private-vs"}' -H "Content-Type: application/json"
# curl -X POST http://127.0.0.1:5000/api/getnsxgroup -d '{"vs_name":"test-create-vm"}' -H "Content-Type: application/json"
# curl -X POST http://127.0.0.1:5000/api/getcert -d '{"vs_name":"demo1"}' -H "Content-Type: application/json"
# curl -X POST http://127.0.0.1:5000/api/getwaf -d '{"vs_name":"demo1"}' -H "Content-Type: application/json"
# curl -X POST http://127.0.0.1:5000/api/getse -d '{"vs_name":"signed-pub"}' -H "Content-Type: application/json"
# curl -X POST http://127.0.0.1:5000/api/getvipsegment -d '{"vs_name":"demo1"}' -H "Content-Type: application/json"
# curl -X POST http://127.0.0.1:5000/api/getseip -d '{"vs_name":"demo1"}' -H "Content-Type: application/json"
# curl -X POST http://127.0.0.1:5000/api/getfqdn -d '{"vs_name":"demo1"}' -H "Content-Type: application/json"
# curl -X POST http://127.0.0.1:5000/api/getsehost -d '{"vs_name":"demo1"}' -H "Content-Type: application/json"
# curl -X POST http://127.0.0.1:5000/api/getnsxroute -d '{"vs_name":"demo1"}' -H "Content-Type: application/json"



# Creating a Flask app
app = Flask(__name__)
cors = CORS(app)

@app.route('/api/createlbaas', methods=['POST'])
def createlbaas():
    args_parser_get= reqparse.RequestParser()
    args_parser_get.add_argument("vs_name", type=str, help="VS Name", required=True)
    args_parser_get.add_argument("app_profile", type=str, help="public or private", required=True)
    args_parser_get.add_argument("count", type=int, help="Number of backend", required=True)
    args_parser_get.add_argument("cert", type=str, help="self-signed or new-cert", required=True)
    args_parser_get = args_parser_get.parse_args()
    a_dict = {}
    a_dict['operation'] = "apply"
    a_dict['vs_name'] = args_parser_get['vs_name']
    a_dict['app_profile'] = args_parser_get['app_profile']
    a_dict['count'] = args_parser_get['count']
    a_dict['cert'] = args_parser_get['cert']
    json_file='/tmp/create_' + a_dict['vs_name'] + '.json'
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    folder="/home/ubuntu/lbaas"
    subprocess.Popen(['/bin/bash', 'lbaas.sh', json_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    output = {}
    output['vs_name'] = args_parser_get['vs_name']
    results = json.dumps(output)
    return results, 201

@app.route('/api/deletelbaas', methods=['DELETE'])
def deletelbaas():
    args_parser_get= reqparse.RequestParser()
    args_parser_get.add_argument("vs_name", type=str, help="VS Name", required=True)
    args_parser_get = args_parser_get.parse_args()
    a_dict = {}
    a_dict['vs_name'] = args_parser_get['vs_name']
    a_dict['operation'] = "destroy"
    json_file='/tmp/destroy_' + a_dict['vs_name'] + '.json'
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    folder="/home/ubuntu/lbaas"
    subprocess.Popen(['/bin/bash', 'lbaas.sh', json_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    output = {}
    output['vs_name'] = args_parser_get['vs_name']
    results = json.dumps(output)
    return results, 201

@app.route('/api/cleanup', methods=['DELETE'])
def cleanup():
    folder="/home/ubuntu/lbaas"
    subprocess.Popen(['/bin/bash', 'cleanup.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    output = {}
    output['cleanup'] = 'on-going'
    results = json.dumps(output)
    return results, 201

@app.route('/api/getapp', methods=['POST'])
def getapp():
    folder="/home/ubuntu/lbaas"
    json_output_file='/tmp/getapp_output.json'
    subprocess.run(['/bin/bash', 'get_app.sh', json_output_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    with open(json_output_file, 'r') as results_json:
        results = json.load(results_json)
    return results, 201

@app.route('/api/getvip', methods=['POST'])
def getvip():
    args_parser_get= reqparse.RequestParser()
    args_parser_get.add_argument("vs_name", type=str, help="VS Name", required=True)
    args_parser_get = args_parser_get.parse_args()
    a_dict = {}
    a_dict['vs_name'] = args_parser_get['vs_name']
    json_file='/tmp/getvip_' + a_dict['vs_name'] + '.json'
    json_output_file='/tmp/getvip_output_' + a_dict['vs_name'] + '.json'
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    folder="/home/ubuntu/lbaas"
    subprocess.run(['/bin/bash', 'get_vip.sh', json_file, json_output_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    with open(json_output_file, 'r') as results_json:
        results = json.load(results_json)
    return results, 201

@app.route('/api/getfqdn', methods=['POST'])
def getfqdn():
    args_parser_get= reqparse.RequestParser()
    args_parser_get.add_argument("vs_name", type=str, help="VS Name", required=True)
    args_parser_get = args_parser_get.parse_args()
    a_dict = {}
    a_dict['vs_name'] = args_parser_get['vs_name']
    json_file='/tmp/getfqdn_' + a_dict['vs_name'] + '.json'
    json_output_file='/tmp/getfqdn_output_' + a_dict['vs_name'] + '.json'
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    folder="/home/ubuntu/lbaas"
    subprocess.run(['/bin/bash', 'get_fqdn.sh', json_file, json_output_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    with open(json_output_file, 'r') as results_json:
        results = json.load(results_json)
    return results, 201

@app.route('/api/getse', methods=['POST'])
def getse():
    args_parser_get= reqparse.RequestParser()
    args_parser_get.add_argument("vs_name", type=str, help="VS Name", required=True)
    args_parser_get = args_parser_get.parse_args()
    a_dict = {}
    a_dict['vs_name'] = args_parser_get['vs_name']
    json_file='/tmp/getse_' + a_dict['vs_name'] + '.json'
    json_output_file='/tmp/getse_output_' + a_dict['vs_name'] + '.json'
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    folder="/home/ubuntu/lbaas"
    subprocess.run(['/bin/bash', 'get_se.sh', json_file, json_output_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    with open(json_output_file, 'r') as results_json:
        results = json.load(results_json)
    return results, 201

@app.route('/api/getsesizing', methods=['POST'])
def getsesizing():
    args_parser_get= reqparse.RequestParser()
    args_parser_get.add_argument("vs_name", type=str, help="VS Name", required=True)
    args_parser_get = args_parser_get.parse_args()
    a_dict = {}
    a_dict['vs_name'] = args_parser_get['vs_name']
    json_file='/tmp/getsesizing_' + a_dict['vs_name'] + '.json'
    json_output_file='/tmp/getsesizing_output_' + a_dict['vs_name'] + '.json'
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    folder="/home/ubuntu/lbaas"
    subprocess.run(['/bin/bash', 'get_se_sizing.sh', json_file, json_output_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    with open(json_output_file, 'r') as results_json:
        results = json.load(results_json)
    return results, 201

@app.route('/api/getcert', methods=['POST'])
def getcert():
    args_parser_get= reqparse.RequestParser()
    args_parser_get.add_argument("vs_name", type=str, help="VS Name", required=True)
    args_parser_get = args_parser_get.parse_args()
    a_dict = {}
    a_dict['vs_name'] = args_parser_get['vs_name']
    json_file='/tmp/getcert_' + a_dict['vs_name'] + '.json'
    json_output_file='/tmp/getcert_output_' + a_dict['vs_name'] + '.json'
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    folder="/home/ubuntu/lbaas"
    subprocess.run(['/bin/bash', 'get_cert.sh', json_file, json_output_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    with open(json_output_file, 'r') as results_json:
        results = json.load(results_json)
    return results, 201

@app.route('/api/getwaf', methods=['POST'])
def getwaf():
    args_parser_get= reqparse.RequestParser()
    args_parser_get.add_argument("vs_name", type=str, help="VS Name", required=True)
    args_parser_get = args_parser_get.parse_args()
    a_dict = {}
    a_dict['vs_name'] = args_parser_get['vs_name']
    json_file='/tmp/getwaf_' + a_dict['vs_name'] + '.json'
    json_output_file='/tmp/getwaf_output_' + a_dict['vs_name'] + '.json'
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    folder="/home/ubuntu/lbaas"
    subprocess.run(['/bin/bash', 'get_waf.sh', json_file, json_output_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    with open(json_output_file, 'r') as results_json:
        results = json.load(results_json)
    return results, 201

@app.route('/api/getnsxgroup', methods=['POST'])
def getnsxgroup():
    args_parser_get= reqparse.RequestParser()
    args_parser_get.add_argument("vs_name", type=str, help="VS Name", required=True)
    args_parser_get = args_parser_get.parse_args()
    a_dict = {}
    a_dict['vs_name'] = args_parser_get['vs_name']
    json_file='/tmp/getnsxgroup_' + a_dict['vs_name'] + '.json'
    json_output_file='/tmp/getnsxgroup_output_' + a_dict['vs_name'] + '.json'
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    folder="/home/ubuntu/lbaas"
    subprocess.run(['/bin/bash', 'get_nsx_group.sh', json_file, json_output_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    with open(json_output_file, 'r') as results_json:
        results = json.load(results_json)
    return results, 201

@app.route('/api/getvipsegment', methods=['POST'])
def getvipsegment():
    args_parser_get= reqparse.RequestParser()
    args_parser_get.add_argument("vs_name", type=str, help="VS Name", required=True)
    args_parser_get = args_parser_get.parse_args()
    a_dict = {}
    a_dict['vs_name'] = args_parser_get['vs_name']
    json_file='/tmp/getvipsegment_' + a_dict['vs_name'] + '.json'
    json_output_file='/tmp/getvipsegment_output_' + a_dict['vs_name'] + '.json'
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    folder="/home/ubuntu/lbaas"
    subprocess.run(['/bin/bash', 'get_vip_segment.sh', json_file, json_output_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    with open(json_output_file, 'r') as results_json:
        results = json.load(results_json)
    return results, 201

@app.route('/api/getseip', methods=['POST'])
def getseip():
    args_parser_get= reqparse.RequestParser()
    args_parser_get.add_argument("vs_name", type=str, help="VS Name", required=True)
    args_parser_get = args_parser_get.parse_args()
    a_dict = {}
    a_dict['vs_name'] = args_parser_get['vs_name']
    json_file='/tmp/getseip_' + a_dict['vs_name'] + '.json'
    json_output_file='/tmp/getseip_output_' + a_dict['vs_name'] + '.json'
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    folder="/home/ubuntu/lbaas"
    subprocess.run(['/bin/bash', 'get_se_ip.sh', json_file, json_output_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    with open(json_output_file, 'r') as results_json:
        results = json.load(results_json)
    return results, 201

@app.route('/api/getsehost', methods=['POST'])
def getsehost():
    args_parser_get= reqparse.RequestParser()
    args_parser_get.add_argument("vs_name", type=str, help="VS Name", required=True)
    args_parser_get = args_parser_get.parse_args()
    a_dict = {}
    a_dict['vs_name'] = args_parser_get['vs_name']
    json_file='/tmp/getsehost_' + a_dict['vs_name'] + '.json'
    json_output_file='/tmp/getsehost_output_' + a_dict['vs_name'] + '.json'
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    folder="/home/ubuntu/lbaas"
    subprocess.run(['/bin/bash', 'get_se_host.sh', json_file, json_output_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    with open(json_output_file, 'r') as results_json:
        results = json.load(results_json)
    return results, 201

@app.route('/api/getnsxroute', methods=['POST'])
def getnsxroute():
    args_parser_get= reqparse.RequestParser()
    args_parser_get.add_argument("vs_name", type=str, help="VS Name", required=True)
    args_parser_get = args_parser_get.parse_args()
    a_dict = {}
    a_dict['vs_name'] = args_parser_get['vs_name']
    json_file='/tmp/getnsxroute_' + a_dict['vs_name'] + '.json'
    json_output_file='/tmp/getnsxroute_output_' + a_dict['vs_name'] + '.json'
    with open(json_file, 'w') as outfile:
        json.dump(a_dict, outfile)
    folder="/home/ubuntu/lbaas"
    subprocess.run(['/bin/bash', 'get_nsx_route.sh', json_file, json_output_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    with open(json_output_file, 'r') as results_json:
        results = json.load(results_json)
    return results, 201

# Start the server
if __name__ == '__main__':
    app.run()