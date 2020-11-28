"""Trigger a dag in airflow via a lambda function."""
import json
from botocore.vendored import requests
import boto3


def get_airflow_private_ip() -> str:
    """Return the private ip address of the running airflow webserver."""
    client = boto3.client("ecs")

    airflow_arn = "${AIRFLOW_ECS_CLUSTER_ARN}"

    task_arns = client.list_tasks(
        cluster=airflow_arn,
        maxResults=1,
        desiredStatus='RUNNING',
    )["taskArns"]
    
    task_details = client.describe_tasks(
        cluster=airflow_arn,
        tasks=task_arns
    )["tasks"][0]["attachments"][0]["details"]
    
    for td in task_details:
        if td["name"] == "privateIPv4Address":
            return td["value"]

    return None


def unpause_dag(airflow_ip: str, dag_id: str) -> None:
    """Unpause a dag via the airflow api."""
    url = f"http://{airflow_ip}:8080/api/experimental/dags/{dag_id}/paused/false"
    res = requests.get(url)
    print(f"unpause_dag returned:\n{res}")


def start_dag(airflow_ip: str, dag_id: str) -> None:
    """Start a dag via the airflow api."""
    url = f"http://{airflow_ip}:8080/api/experimental/dags/{dag_id}/dag_runs"
    payload = {}
    headers = {
        "Cache-Control": "no-cache"
    }
    res = requests.post(url, data=json.dumps(payload), headers=headers)
    print(f"start_dag returned:\n{res}")


def lambda_handler(event: dict, context: dict) -> dict:
    """Entrypoint for this lambda function."""
    airflow_ip = get_airflow_private_ip()
    dag_id = "0_sync_dags_in_s3_to_local_airflow_dags_folder"

    unpause_dag(airflow_ip, dag_id)
    start_dag(airflow_ip, dag_id)

    return {
        "statusCode": 200
    }
