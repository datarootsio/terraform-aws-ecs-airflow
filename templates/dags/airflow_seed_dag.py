import datetime
import os
from os import listdir
from os.path import isfile, join
from typing import Dict

import boto3
from airflow import DAG
from airflow.operators.bash_operator import BashOperator
from airflow.operators.python_operator import PythonOperator

# The bucket name and key the of where dags are stored in S3
S3_BUCKET_NAME = "${BUCKET_NAME}"
# airflow home directory where dags & plugins reside
AIRFLOW_HOME = "${AIRFLOW_HOME}"

args = {
    "start_date": datetime.datetime(2022,9,1),
}

# we prefix the dag with '0' to make it the first dag
with DAG(
    dag_id="0_sync_dags_in_s3_to_local_airflow_dags_folder_all_files",
    default_args=args,
    schedule_interval=None
) as dag:
    list_dags_before = BashOperator(
        task_id="list_dags_before",
        bash_command="find ${AIRFLOW_HOME}/dags -not -path '*__pycache__*'",
    )

    sync_dags = BashOperator(
        task_id="sync_dag_s3_to_airflow",
        bash_command=f"python -m awscli s3 sync --include='*' --size-only --delete s3://{S3_BUCKET_NAME}/dags/ {AIRFLOW_HOME}/dags/"
    )

    sync_plugins = BashOperator(
        task_id="sync_plugins_s3_to_airflow",
        bash_command=f"python -m awscli s3 sync --include='*' --size-only --delete s3://{S3_BUCKET_NAME}/plugins/ {AIRFLOW_HOME}/plugins/"
    )

    refresh_dag_bag = BashOperator(
        task_id="refresh_dag_bag",
        bash_command="python -c 'from airflow.models import DagBag; d = DagBag();'",
    )

    list_dags_after = BashOperator(
        task_id="list_dags_after",
        bash_command="find ${AIRFLOW_HOME}/dags -not -path '*__pycache__*'",
    )

    (
        list_dags_before >>
        [sync_dags, sync_plugins] >>
        refresh_dag_bag >>
        list_dags_after
    )
