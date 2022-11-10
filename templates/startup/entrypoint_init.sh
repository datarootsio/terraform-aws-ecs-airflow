#!/bin/bash

echo "[INFO] Starting up airflow init"

# commands change between version so get the major version here
airflow_major_version=$(echo ${AIRFLOW_VERSION} | awk -F. '{ print $1 }')

# Install python packages through req.txt and pip (if exists)
if [[ -f "${AIRFLOW_HOME}/startup/requirements.txt" ]]; then
    echo "[INFO] requirements.txt provided. Installing requirements.txt dependencies with pip."
    python -m pip install --upgrade pip
    python -m pip install -r ${AIRFLOW_HOME}/startup/requirements.txt --user
fi

# prepare database if needed
echo "[INFO] Check and prepare database"
if ! python ./startup/init.py ; then
  exit 1
fi

# airflow
echo "[INFO] Running airflow db init"
if [[ "$airflow_major_version" == "1" ]]; then
    airflow initdb
else
   
    airflow db upgrade
    airflow db init
fi

# add admin user if rbac enabled and not exists
if [[ "${RBAC_AUTH}" == "true" ]]; then
  echo "[INFO] Enabling RBAC authentication"
    # get the amount of users to see if we need to add a default user
    amount_of_users="-9999"
    if [[ "$airflow_major_version" == "1" ]]; then
        amount_of_users=$(python -c 'import sys;print((sys.argv.count("│") // 7) - 1)' $(airflow list_users))
    else
        amount_of_users=$(python -c 'import sys;cmd_in = " ".join(sys.argv);print((cmd_in.count("|") // 5) - 1 if "No data found" not in cmd_in else 0)' $(airflow users list))  
    fi

    if [[ "$amount_of_users" == "0" ]]; then
        echo "[INFO] Adding admin users, users list is empty!"
        if [[ "$airflow_major_version" == "1" ]]; then
            airflow create_user -r Admin -u ${RBAC_USERNAME} -e ${RBAC_EMAIL} -f ${RBAC_FIRSTNAME} -l ${RBAC_LASTNAME} -p ${RBAC_PASSWORD}
        else
            airflow users create -r Admin -u ${RBAC_USERNAME} -e ${RBAC_EMAIL} -f ${RBAC_FIRSTNAME} -l ${RBAC_LASTNAME} -p ${RBAC_PASSWORD}  
        fi
    else
        echo "[INFO] No admin user added, users already exists!"
    fi
else
    airflow users delete -u ${AIRFLOW_USER_NAME}
    airflow users create --role Admin --username ${AIRFLOW_USER_NAME} --email admin --firstname admin --lastname admin --password ${AIRFLOW_USER_PASSWORD}
fi