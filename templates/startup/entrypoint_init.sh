echo "starting the init"
airflow initdb

# add admin user if not exists
if [ "${RBAC_AUTH}" == "true" ]; then
    # todo if no users add admin user
    airflow list_users
    airflow create_user -r Admin -u admin -e admin@admin.com -f Admin -l airflow -p admin
fi