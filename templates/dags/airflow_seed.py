import datetime
from typing import Dict
from datetime import timedelta

from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from airflow.operators.bash_operator import BashOperator
from airflow.utils.dates import days_ago
from airflow import AirflowException

from airflow.api.common.experimental.delete_dag import delete_dag

import boto3
import re
from os import listdir
import os
from os.path import isfile, join

# The name of this file
seed_dag_file_name = os.path.basename(__file__)

# The bucket name and key the of where dags are stored in S3
s3_bucket_name_dags = "${BUCKET_NAME}"
s3_key_dags = "dags"
# Path to the local folder on the container
# where the dags are stored
folder_local = "${AIRFLOW_HOME}/dags"

args = {
    "start_date": datetime.datetime(2020, 10, 16),
}

with DAG(
    dag_id="_sync_dags_in_s3_to_local_airflow_dags_folder",
    default_args=args,
    schedule_interval=None
) as dag:
    list_dags_before = BashOperator(
        task_id="list_dags_before",
        bash_command="ls ${AIRFLOW_HOME}/dags",
    )

    def get_dag_id(dag_file_path: str) -> str:
        """Gets the dag id in a file."""
        with open(dag_file_path, "r") as file:
            all_python_code = file.read()

        dag_id_search = re.search(
            'dag_id="(.*)",.*',
            all_python_code,
            re.IGNORECASE
        )

        dag_id = None
        if dag_id_search:
            dag_id = dag_id_search.group(1)

        if dag_id == None:
            raise Exception("No dag_id found")

        return dag_id

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
        # also delete the dag
        files_in_dag_folder = [f for f in listdir(folder_local) if isfile(join(folder_local, f))]

        for file_name in files_in_dag_folder:
            dag_file_path = f"{folder_local}/{file_name}"
            if file_name not in dag_files_in_s3:
                dag_id = get_dag_id(dag_file_path)
                print(f"Removing dag file: {folder_local}/{file_name}")
                os.remove(f"{folder_local}/{file_name}")
                print(f"Removing dag with id: {dag_id}")
                delete_dag(dag_id)

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
