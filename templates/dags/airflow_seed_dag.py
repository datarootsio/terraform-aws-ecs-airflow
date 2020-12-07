import os
from os import listdir
from os.path import isfile, join

import datetime
from typing import Dict

from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from airflow.operators.bash_operator import BashOperator
from airflow.operators.dummy_operator import DummyOperator

import boto3

from commons.utils import create_dummy_task

# The bucket name and key the of where dags are stored in S3
S3_BUCKET_NAME = "${BUCKET_NAME}"
# airflow home directory where dags & plugins reside
AIRFLOW_HOME = "${AIRFLOW_HOME}"

args = {
    "start_date": datetime.datetime(${YEAR}, ${MONTH}, ${DAY}),
}

# we prefix the dag with '0' to make it the first dag
with DAG(
    dag_id="sync_airflow_from_s3",
    default_args=args,
    schedule_interval=None
) as dag:

    start_task = DummyOperator(
        dag=dag,
        task_id="start_task"
    )
    
    sync_dags = BashOperator(
        task_id="sync_dag_s3_to_airflow",
        bash_command=f"python -m awscli s3 sync --exclude='*' --include='*.py' --size-only --delete s3://{S3_BUCKET_NAME}/dags/ {AIRFLOW_HOME}/dags/"
    )

    sync_plugins = BashOperator(
        task_id="sync_plugins_s3_to_airflow",
        bash_command=f"python -m awscli s3 sync --exclude='*' --include='*.py' --size-only --delete s3://{S3_BUCKET_NAME}/plugins/ {AIRFLOW_HOME}/plugins/"
    )

    refresh_dag_bag = BashOperator(
        task_id="refresh_dag_bag",
        bash_command="python -c 'from airflow.models import DagBag; d = DagBag();'",
    )

    list_dags_after = BashOperator(
        task_id="list_dags_after",
        bash_command="ls ${AIRFLOW_HOME}/dags",
    )

    dag >> start_task >> [sync_dags, sync_plugins] >> refresh_dag_bag >> list_dags_after
