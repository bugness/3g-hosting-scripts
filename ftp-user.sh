#!/bin/bash

if [ -z $1 ] || [ -z $2 ]; then
    echo "Использование: ./ftp-user.sh {create|ban|unban|delete} \$user \$home_dir"
    exit 1;
fi

backup_dir="/home/USER/backup"
id=`cat /etc/passwd | grep $2 | awk -F: '{print $3}'`
user=$2
password=`cat /dev/urandom | tr -d -c _A-Z-a-z-0-9 | head -c9`
home=$3

mysql_user="pureftpd"
mysql_pass="PASSWORD"
mysql="mysql --user=${mysql_user} --password=${mysql_pass} pureftpd"

case $1 in
    create)
        if [ -z ${home} ]; then
            home=$2
        fi
        echo "INSERT INTO \`ftpd\` (\`User\`, \`status\`, \`Password\`, \`Uid\`, \`Gid\`, \`Dir\`, \`ULBandwidth\`, \`DLBandwidth\`, \`comment\`, \`ipaccess\`, \`QuotaSize\`, \`QuotaFiles\`) VALUES ('${user}', '1', MD5('${password}'), '${id}', '${id}', '/var/www/${home}', '500', '500', '', '*', '100', '0');" | ${mysql}
        echo "# FTP USERNAME: ${user} PASSWORD: ${password} " >> ${backup_dir}/${user}.access
        ;;
    ban)
        echo "UPDATE \`ftpd\` SET \`status\` = '0' WHERE \`User\` = '${user}'" | ${mysql}
        ;;
    unban)
        echo "UPDATE \`ftpd\` SET \`status\` = '1' WHERE \`User\` = '${user}'" | ${mysql}
        ;;
    delete)
        echo "DELETE FROM \`ftpd\` WHERE \`User\` = '${user}'" | ${mysql}
        ;;
    *)
        echo "Использование: ./ftp-user.sh {create|ban|unban|delete} \$user \$home_dir"
        ;;
esac
