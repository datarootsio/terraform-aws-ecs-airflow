import os
from os import listdir
from os.path import isfile, join

import datetime
from typing import Dict

from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from airflow.operators.bash_operator import BashOperator

import boto3

# The name of this file
seed_dag_file_name = os.path.basename(__file__)

# The bucket name and key the of where dags are stored in S3
s3_bucket_name_dags = "${BUCKET_NAME}"
s3_key_dags = "dags"
# Path to the local folder on the container
# where the dags are stored
folder_local = "${AIRFLOW_HOME}/dags"

args = {
    "start_date": datetime.datetime(${YEAR}, ${MONTH}, ${DAY}),
}

# we prefix the dag with '0' to make it the first dag
with DAG(
    dag_id="0_sync_dags_in_s3_to_local_airflow_dags_folder",
    default_args=args,
    schedule_interval=None
) as dag:
    list_dags_before = BashOperator(
        task_id="list_dags_before",
        bash_command="ls ${AIRFLOW_HOME}/dags",
    )

    def sync_s3_dags_to_local_dags(**context: Dict) -> None:
        """Syncs an S3 bucket with a local folder in the airflow container."""
        s3_resource = boto3.resource("s3")
        bucket = s3_resource.Bucket(s3_bucket_name_dags)

        dag_files_in_s3 = [seed_dag_file_name]
        # get files from s3 and download them to the local folder
        for object in bucket.objects.filter(Prefix=s3_key_dags):
            file_name = object.key.split("/")[-1]
            dag_files_in_s3.append(file_name)
            print(f"Adding file: {folder_local}/{file_name}")
            bucket.download_file(object.key, f"{folder_local}/{file_name}")

        # remove all the files and dags not in s3 from the local folder
        files_in_dag_folder = [f for f in listdir(folder_local) if isfile(join(folder_local, f))]

        for file_name in files_in_dag_folder:
            dag_file_path = f"{folder_local}/{file_name}"
            if file_name not in dag_files_in_s3:
                print(f"Removing dag file: {folder_local}/{file_name}")
                os.remove(f"{folder_local}/{file_name}")

    sync_dags = PythonOperator(
        task_id="sync_dags_in_s3_to_local_dags",
        python_callable=sync_s3_dags_to_local_dags,
        provide_context=True,
    )

    refresh_dag_bag = BashOperator(
        task_id="refresh_dag_bag",
        bash_command="python -c 'from airflow.models import DagBag; d = DagBag();'",
    )

    list_dags_after = BashOperator(
        task_id="list_dags_after",
        bash_command="ls ${AIRFLOW_HOME}/dags",
    )

    list_dags_before >> sync_dags >> refresh_dag_bag >> list_dags_after
