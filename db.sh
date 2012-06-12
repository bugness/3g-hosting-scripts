#!/bin/bash

if [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
    echo "Использование: ./db.sh {create|backup|delete} \$user \$dbname"
    exit 1;
fi

user="$2_$3"
password=`cat /dev/urandom | tr -d -c _A-Z-a-z-0-9 | head -c9`

date=`date +%Y%m%d`
backup_dir="/root/backup"
gzip="/bin/gzip"
mysql="/usr/bin/mysql"
mysqldump="/usr/bin/mysqldump"
query_preffix="-u root -pPASSWORD"

case "$1" in
    create)
        ${mysql} ${query_preffix} --execute="CREATE DATABASE \`${user}\`;"
        ${mysql} ${query_preffix} --execute="GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON \`${user}\`.* TO '${user}'@'localhost' IDENTIFIED BY '${password}'; FLUSH PRIVILEGES;"
        echo "# MySQL://${user}:${password}@localhost/${user}" >> ${backup_dir}/$2.access
        echo "${user}" >> ${backup_dir}/$2.bases
    ;;
    backup)
        ${mysqldump} ${query_preffix} ${user} | ${gzip} > ${backup_dir}/${user}-${date}.sql.gz
    ;;
    delete)
        ${mysqldump} ${query_preffix} ${user} | ${gzip} > ${backup_dir}/${user}-${date}.sql.gz
        ${mysql} ${query_preffix} --execute="DROP DATABASE IF EXISTS \`${user}\`;"
        ${mysql} ${query_preffix} --execute="REVOKE ALL PRIVILEGES ON *.* FROM '${user}'@'localhost';"
        ${mysql} ${query_preffix} --execute="REVOKE GRANT OPTION ON *.* FROM '${user}'@'localhost';"
        ${mysql} ${query_preffix} --execute="DELETE FROM mysql.user WHERE User='${user}' and Host='localhost';"
        cat ${backup_dir}/$2.bases | grep -v ${user} | cat > ${backup_dir}/$2.bases
    ;;
    *)
        echo "Использование: ./db.sh {create|backup|delete} \$user \$dbname"
    ;;
esac
