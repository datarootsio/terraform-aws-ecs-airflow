"""Trigger a dag in airflow via a lambda function."""
import json
from botocore.vendored import requests
import boto3


def get_airflow_private_ip() -> str:
    """Return the private ip address of the running airflow webserver."""
    client = boto3.client("ecs")

    airflow_arn = "put arn here"

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


def unpause_dag(airflow_ip: str, dag_id: str) -> None:
    """Unpause a dag via the airflow api."""
    url = f"http://{airflow_ip}:8080/api/experimental/dags/{dag_id}/paused/false"
    requests.get(url)


def start_dag(airflow_ip: str, dag_id: str) -> None:
    """Start a dag via the airflow api."""
    url = f"http://{airflow_ip}:8080/api/experimental/dags/{dag_id}/dag_runs"
    payload = {}
    headers = {
        "Cache-Control": "no-cache"
    }
    requests.post(url, data=json.dumps(payload), headers=headers)


def lambda_handler(event: dict, context: dict) -> dict:
    """Entrypoint for this lambda function."""
    airflow_ip = get_airflow_private_ip()
    dag_id = "0_sync_dags_in_s3_to_local_airflow_dags_folder"

    unpause_dag(airflow_ip, dag_id)
    start_dag(airflow_ip, dag_id)

    return {
        "statusCode": 200
    }
