echo "Starting up airflow scheduler"
# Sanity check the dags
ls /opt/airflow/dags

# Install boto and awscli for the seed dag
python -m pip install awscli --user

# Check if the requirements file exists and fetch it if it does
if curl --head --fail -s ${S3_URL_REQUIREMENTS_FILE} > /dev/null; then
    echo "requirements.txt provided, installing it with pip"
    # Download the requirements.txt file to the AIRFLOW_HOME directory
    curl -s -o "${AIRFLOW_HOME}/requirements.txt" ${S3_URL_REQUIREMENTS_FILE}

    # Install the requirements using pip
    pip install -r "${AIRFLOW_HOME}/requirements.txt" --user
else
    echo "requirements.txt provided, but not found in S3 bucket"
fi

# Run the airflow webserver
airflow scheduler