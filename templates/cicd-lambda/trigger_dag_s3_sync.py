import json
from botocore.vendored import requests
import boto3
import os

env = os.environ["ENV"]


def get_airflow_private_ip():
    client = boto3.client("ecs")

    airflow_arn = f"arn:aws:ecs:eu-west-1:283774148357:cluster/vrt-datalake-airflow-cluster-{env}"

    task_arn = client.list_tasks(
        cluster=airflow_arn,
        maxResults=1,
        desiredStatus='RUNNING',
    )["taskArns"][0]

    task_details = client.describe_tasks(
        cluster=airflow_arn,
        tasks=[
            task_arn,
        ]
    )["tasks"][0]["attachments"][0]["details"]

    for td in task_details:
        if td["name"] == "privateIPv4Address":
            return td["value"]

    return None


def unpause_dag(airflow_ip, dag_id):
    url = f"http://{airflow_ip}:8080/api/experimental/dags/{dag_id}/paused/false"
    r = requests.get(url)


def start_dag(airflow_ip, dag_id):
    url = f"http://{airflow_ip}:8080/api/experimental/dags/{dag_id}/dag_runs"
    payload = {}
    headers = {
        "Cache-Control": "no-cache"
    }
    r = requests.post(url, data=json.dumps(payload), headers=headers)


def lambda_handler(event, context):
    airflow_ip = get_airflow_private_ip()
    dag_id = "_sync_dags_in_s3_to_local_airflow_dags_folder"

    unpause_dag(airflow_ip, dag_id)
    start_dag(airflow_ip, dag_id)

    return {
        'statusCode': 200
    }