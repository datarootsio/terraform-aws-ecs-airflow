"""
import datetime
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

# the name of this file
seed_dag_file_name = os.path.basename(__file__)

args = {
    "start_date": datetime.datetime(2020, 7, 7),
}

# prefix with "_" to make it the frist dag
with DAG(
    dag_id="_sync_dags_in_s3_to_local_airflow_dags_folder",
    default_args=args,
    schedule_interval=None
) as dag:
    def get_dag_id(dag_file_path):
        with open(dag_file_path, "r") as file:
            all_python_code = file.read()

        dag_id_search = re.search('dag_id="(.*)",.*', all_python_code, re.IGNORECASE)

        dag_id = None
        if dag_id_search:
            dag_id = dag_id_search.group(1)

        if dag_id == None:
            raise Exception("No dag_id found")

        return dag_id

    def sync_s3_dags_to_local_dags(**context):
        bucket_name = "${BUCKET_NAME}"
        remote_directory_name = "airflow/dags/"

        folder_local = "/usr/local/airflow/dags"

        s3_resource = boto3.resource("s3")
        bucket = s3_resource.Bucket(bucket_name)

        dag_files_in_s3 = [seed_dag_file_name]
        # get files from s3
        for object in bucket.objects.filter(Prefix=remote_directory_name):
            file_name = object.key.split("/")[-1]
            if "_wf.py" in file_name:
                dag_files_in_s3.append(file_name)
                print(f"Adding file: {folder_local}/{file_name}")
                bucket.download_file(object.key, f"{folder_local}/{file_name}")

        # remove all the files and dags not in s3
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

    list_dags_before_delete = BashOperator(
        task_id="list_dags_before_delete",
        bash_command="ls /usr/local/airflow/dags",
    )

    refresh_dag_bag = BashOperator(
        task_id="refresh_dag_bag",
        bash_command="python -c 'from airflow.models import DagBag; d = DagBag();'",
    )

    list_dags_after_delete = BashOperator(
        task_id="list_dags_after_delete",
        bash_command="ls /usr/local/airflow/dags",
    )

    sync_dags >> list_dags_before_delete >> refresh_dag_bag >> list_dags_after_delete
"""