echo "Starting up airflow"
ls /opt/airflow/dags
# Make it so airflow can run tasks in parallel
export AIRFLOW__CORE__EXECUTOR="LocalExecutor"
# Set the Postgres database conn uri
export AIRFLOW__CORE__SQL_ALCHEMY_CONN="postgresql+psycopg2://${POSTGRES_URI}"
# Intall python packages through req.txt and pip
python -m pip install -r /startup/requirements.txt --user
# Create a db connection
airflow initdb
# Run the airflow webserver
exec airflow webserver