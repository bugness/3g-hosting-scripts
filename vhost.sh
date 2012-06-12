#!/bin/bash

if [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
    echo "Использование: ./vhost.sh {create|delete} \$user \$domain"
    exit 1;
fi

user="$2"
domain="$3"

backup_dir="/root/backup"
port=$(( `cat ${backup_dir}/last_port.txt` + 1 ))
home="/home/${user}"
public_dir="${home}/${domain}/public"

case "$1" in
    create)
        mkdir -p ${public_dir}
        chown ${user}:${user} ${public_dir} ${public_dir}/../
        echo "${port}" > ${backup_dir}/last_port.txt

        # virtualhost для nginx
        cat << EOF > /etc/nginx/sites-available/${domain}
server {
        listen 80;
        server_name ${domain};
        access_log ${home}/logs/${domain}-access.log;
        error_log ${home}/logs/${domain}-error.log;

        location ~* \.(jpg|jpeg|gif|png|css|zip|tgz|gz|js|bz2|pdf|tar|wav|bmp|rtf|swf|ico|flv|txt|xml)$ {
                root            ${public_dir};
                index           index.html index.php;
                access_log      off;
                expires         30d;
        }

        location ~ /\.ht {
                deny all;
        }

        location ~ /.svn/ {
                deny all;
        }

        location / {
                try_files       \$uri \$uri/ @rewrite;
        }

        location ~ \.php$ {
                include fastcgi_params;
                fastcgi_param   SCRIPT_FILENAME ${public_dir}\$fastcgi_script_name;
                fastcgi_param   DOCUMENT_ROOT   ${public_dir};
                fastcgi_pass    127.0.0.1:${port};
        }

        location @rewrite {
                include fastcgi_params;
                fastcgi_param  SCRIPT_FILENAME  ${public_dir}/index.php;
                fastcgi_param  DOCUMENT_ROOT    ${public_dir};

                fastcgi_intercept_errors        on;
                fastcgi_ignore_client_abort     off;
                fastcgi_connect_timeout         60;
                fastcgi_send_timeout            180;
                fastcgi_read_timeout            180;
                fastcgi_buffer_size             128k;
                fastcgi_buffers                 4 256k;
                fastcgi_busy_buffers_size       256k;
                fastcgi_temp_file_write_size    256k;

                fastcgi_pass    127.0.0.1:${port};
                fastcgi_index   index.php;
        }
}
EOF

        # pool для php-fpm
        cat << EOF > /etc/php5/fpm/sites-available/${domain}.conf
[${domain}]

user = phpd
group = ${user}

listen = 127.0.0.1:${port}
listen.mode = 0666

pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 50

request_terminate_timeout = 75

chdir = ${home}/${domain}

catch_workers_output = yes
security.limit_extensions =

php_admin_value[open_basedir] = "${home}/${domain}:/usr/share/php:."
php_admin_value[upload_tmp_dir] = "${home}/tmp"
php_admin_value[session.save_path] = "${home}/tmp"
EOF

        # активируем virtualhost
        ln -s /etc/php5/fpm/sites-available/${domain}.conf /etc/php5/fpm/pool.d/
        ln -s /etc/nginx/sites-available/${domain} /etc/nginx/sites-enabled/

        # перезапускаем веб-сервер
        service php5-fpm restart
        service nginx reload
        echo "# HTTP://${domain}" >> ${backup_dir}/${user}.access
        echo "${domain}" >> ${backup_dir}/${user}.vhosts
    ;;
    delete)
        # деактивируем virtualhost
        unlink /etc/nginx/sites-enabled/${domain}
        unlink /etc/php5/fpm/pool.d/${domain}.conf

        # перезапускаем веб-сервер
        service nginx reload
        service php5-fpm restart

        cat ${backup_dir}/${user}.vhosts | grep -v ${domain} | cat > ${backup_dir}/${user}.vhosts
    ;;
    *)
        echo "Использование: ./vhost.sh {create|delete} \$user \$domain"
    ;;
esac
