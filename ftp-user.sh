#!/bin/bash

if [ -z $1 ] || [ -z $2 ]; then
    echo "Use: ./ftp-user.sh {create|ban|unban|delete} \$user \$home_dir"
    exit 1;
fi

script_path=`dirname $0`

if [ ! -e ${script_path}/.env ]; then
  echo "Please create config file .env"
  exit 1
fi

id=`cat /etc/passwd | grep $2 | awk -F: '{print $3}'`
user=$2
password=`cat /dev/urandom | tr -d -c _A-Z-a-z-0-9 | head -c9`
home=$3

mysql="mysql --user=${mysql_user} --password=${mysql_pass} pureftpd"

case $1 in
    create)
        if [ -z ${home} ]; then
            home=$2
        fi
        echo "INSERT INTO \`ftpd\` (\`User\`, \`status\`, \`Password\`, \`Uid\`, \`Gid\`, \`Dir\`, \`ULBandwidth\`, \`DLBandwidth\`, \`comment\`, \`ipaccess\`, \`QuotaSize\`, \`QuotaFiles\`) VALUES ('${user}', '1', MD5('${password}'), '${id}', '${id}', '/var/www/${home}', '500', '500', '', '*', '100', '0');" | ${mysql}
        echo "# FTP USERNAME: ${user} PASSWORD: ${password} " >> ${backup_path}/${user}.access
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
        echo "Use: ./ftp-user.sh {create|ban|unban|delete} \$user \$home_dir"
        ;;
esac
