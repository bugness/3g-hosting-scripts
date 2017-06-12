#!/bin/bash

if [ -z $1 ] || [ -z $2 ]; then
    echo "Use: ./db-user.sh {create|backup|delete} \$user"
    exit 1;
fi

script_path=`dirname $0`

if [ ! -e ${script_path}/.env ]; then
  echo "Please create config file .env"
  exit 1
fi


user="$2"
password=`cat /dev/urandom | tr -d -c _A-Z-a-z-0-9 | head -c9`
gzip="/usr/bin/gzip"
mysql="/usr/bin/mysql"
mysqldump="/usr/bin/mysqldump"
mysql_credentials="-u ${db_user} -p${db_pass}"

case "$1" in
    create)
        ${mysql} ${query_preffix} --execute="CREATE DATABASE \`${user}\`;"
        ${mysql} ${query_preffix} --execute="GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON \`${user}\`.* TO '${user}'@'localhost' IDENTIFIED BY '${password}'; FLUSH PRIVILEGES;"
        echo "# MySQL DB DATABASE: ${user} USERNAME: ${user} PASSWORD: ${password}" >> ${backup_path}/${user}.access
        ;;
    backup)
        ${mysqldump} ${query_preffix} ${user} | ${gzip} > ${backup_path}/${user}.sql.gz
        ;;
    delete)
        ${mysqldump} ${query_preffix} ${user} | ${gzip} > ${backup_path}/${user}.sql.gz
        ${mysql} ${query_preffix} --execute="DROP DATABASE IF EXISTS \`${user}\`;"
        ${mysql} ${query_preffix} --execute="REVOKE ALL PRIVILEGES ON *.* FROM '${user}'@'localhost';"
        ${mysql} ${query_preffix} --execute="REVOKE GRANT OPTION ON *.* FROM '${user}'@'localhost';"
        ${mysql} ${query_preffix} --execute="DELETE FROM mysql.user WHERE User='${user}' and Host='localhost';"
        ;;
    *)
        echo "Use: ./db-user.sh {create|backup|delete} \$user"
        ;;
esac
