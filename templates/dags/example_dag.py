from datetime import timedelta, datetime

from airflow import DAG
from airflow.operators.dummy_operator import DummyOperator
from airflow import AirflowException

args = {
    "owner": "dataroots",
    "start_date": datetime(2020, 10, 12),
}

with DAG(
    dag_id="example_dag",
    catchup=False,
    max_active_runs=1,
    default_args=args,
    schedule_interval="*/5 * * * *"
) as dag:
    task_a = DummyOperator(
        task_id="task_a"
    )

    task_b = DummyOperator(
        task_id="task_b"
    )
    task_c = DummyOperator(
        task_id="task_c"
    )

    task_d = DummyOperator(
        task_id="task_d"
    )

    task_a >> [task_b, task_c] >> task_d
