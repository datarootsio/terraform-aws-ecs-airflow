echo "starting the init"
exec airflow initdb

# TODO: add admin user if rbac is enabled and admin user doesn't exist