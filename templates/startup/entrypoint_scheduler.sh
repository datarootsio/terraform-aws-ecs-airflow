echo "Starting up airflow scheduler"
# Sanity check the dags
ls /opt/airflow/dags

sudo apt update

sudo apt install software-properties-common build-essential python3.7 libpq-dev build-essential libssl-dev libffi-dev python3-distutils vim

export DBT_PROFILES_DIR=/opt/airflow/dags/dbt

curl https://bootstrap.pypa.io/get-pip.py --output get-pip.py

python3.7 get-pip.py

python3.7 -m pip install dbt-postgres


# Install boto and awscli for the seed dag
python -m pip install awscli --user

# Intall python packages through req.txt and pip (if exists)
if [[ -f "${AIRFLOW_HOME}/startup/requirements.txt" ]]; then
    echo "requirements.txt provided, installing it with pip"
    python -m pip install -r ${AIRFLOW_HOME}/startup/requirements.txt --user
fi
# Run the airflow webserver
airflow scheduler