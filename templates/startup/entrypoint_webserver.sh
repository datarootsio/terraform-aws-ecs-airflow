echo "Starting up airflow"
ls /opt/airflow/dags

# Intall python packages through req.txt and pip
python -m pip install -r ${AIRFLOW_HOME}/startup/requirements.txt --user
# Create a db connection
airflow initdb
# Run the airflow webserver
exec airflow webserver