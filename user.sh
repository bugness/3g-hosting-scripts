#!/bin/bash

if [ -z $1 ] || [ -z $2 ]; then
    echo "Использование: ./user.sh {create|delete} \$user"
    exit 1;
fi

user="$2"
password=`cat /dev/urandom | tr -d -c _A-Z-a-z-0-9 | head -c16`

scripts_dir="/root/scripts"
backup_dir="/root/backup"
work_dir="/home"
home="${work_dir}/${user}"

case "$1" in
    create)
        mkdir -p ${home}/{logs,private,tmp}
        groupadd ${user}
        useradd -c "Hosting User" -b ${work_dir} -g ${user} -G sftponly -s /bin/false ${user}
        echo "${user}:${password}" | chpasswd
        chown -R ${user}:${user} ${home}
        chown root:${user} ${home}
        chmod -R 0750 ${home}
        chmod 0700 ${home}/{logs,private}
        chmod 0770 ${home}/tmp
        usermod -a -G ${user} www-data
        echo "# SFTP://${user}:${password}@dev.triganz.org:3322/" >> ${backup_dir}/${user}.access
    ;;
    delete)
        # бекап
        date=`date +%Y%m%d`
        rm -rf ${home}/tmp/*
        for domain in `grep -v ^# ${backup_dir}/${user}.vhosts | awk '{print $1}'`; do
            ${scripts_dir}/vhost.sh delete ${user} ${domain}
        done
        for dbname in `grep -v ^# ${backup_dir}/${user}.bases | awk '{print $1}'`; do
            ${scripts_dir}/db.sh delete ${user} ${dbname}
        done
        tar zcf ${backup_dir}/${user}-${date}.tar.gz ${home}

        # Удаляем пользователя и группу
        userdel -rf ${user}
        groupdel ${user}
    ;;
    *)
        echo "Использование: ./user.sh {create|delete} \$user"
    ;;
esac
