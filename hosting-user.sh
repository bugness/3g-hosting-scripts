#!/bin/bash

if [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
    echo "Use: ./hosting-user.sh {create|ban|unban|delete} \$user \$domain"
    exit 1;
fi

script_path=`dirname $0`

if [ ! -e ${script_path}/.env ]; then
  echo "Please create config file .env"
  exit 1
fi

user="$2"
domain="$3"

home="${local_path}/${user}"

case "$1" in
    create)
        mkdir -p ${home}/{logs,public_html,tmp}
        groupadd ${user}
        useradd -c "Hosting User" -b ${local_path} -g ${user} -s /bin/false ${user}
        chown -R ${user}:${user} ${home}
        chmod -R 0750 ${home}
        chmod 0770 ${home}/tmp
        usermod -a -G ${user} www-data

        # virtualhost for apache2
        cat << EOF > /etc/apache2/sites-available/${domain}
<VirtualHost *:81>
    ServerAdmin webmaster@localhost
    ServerName ${domain}

    DocumentRoot ${home}/public_html
    <Directory />
        Options FollowSymLinks
        AllowOverride All
    </Directory>
    <Directory ${home}/public_html/>
        Options -Indexes FollowSymLinks MultiViews
        AllowOverride All
        Order allow,deny
        allow from all
    </Directory>

    <IfModule mpm_itk_module>
            AssignUserId ${user} ${user}
    </IfModule>

    ErrorLog ${home}/logs/error.log

    LogLevel warn

    <IfModule mod_php5.c>
        php_admin_value open_basedir "${home}/:."
        php_admin_value safe_mode "on"
        php_admin_value upload_tmp_dir "${home}/tmp"
        php_admin_value session.save_path "${home}/tmp"
    </IfModule>
</VirtualHost>
EOF

        # virtualhost for nginx
        cat << EOF > /etc/nginx/sites-available/${domain}
server {
    listen 80;
    server_name ${domain};
    access_log ${home}/logs/access.log;
    location ~* \.(jpg|jpeg|gif|png|css|zip|tgz|gz|rar|bz2|pdf|tar|wav|bmp|rtf|swf|ico|flv|txt|xml)$ {
        root ${home}/public_html/;
        index index.html index.php;
        access_log off;
        expires 30d;
    }
    location ~ /\.ht {
        deny all;
    }
    location / {
        proxy_pass http://127.0.0.1:81/;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-for \$remote_addr;
        proxy_set_header Host \$host;
        proxy_connect_timeout 60;
        proxy_send_timeout 90;
        proxy_read_timeout 90;
        proxy_redirect off;
        proxy_set_header Connection close;
        proxy_pass_header Content-Type;
        proxy_pass_header Content-Disposition;
        proxy_pass_header Content-Length;
    }
}
EOF

        # virtualhost activation
        a2ensite ${domain}
        cd /etc/nginx/sites-enabled/
        ln -s /etc/nginx/sites-available/${domain}

        # reload configs of web servers
        /etc/init.d/apache2 reload
        /etc/init.d/nginx reload
        echo "# Web Hosting domain: ${domain}" >> ${backup_path}/${user}.access

        ;;
    ban)
        # virtualhost deactivation
        a2dissite ${domain}
        cd /etc/nginx/sites-enabled/
        unlink /etc/nginx/sites-available/${domain}

        # reload configs of web servers
        /etc/init.d/apache2 reload
        /etc/init.d/nginx reload

        ;;
    unban)
        # virtualhost activation
        a2ensite ${domain}
        cd /etc/nginx/sites-enabled/
        ln -s /etc/nginx/sites-available/${domain}

        # reload configs of web servers
        /etc/init.d/apache2 reload
        /etc/init.d/nginx reload

        ;;
    delete)
        # virtualhost deactivation
        a2dissite ${domain}
        cd /etc/nginx/sites-enabled/
        unlink /etc/nginx/sites-available/${domain}

        # reload configs of web servers
        /etc/init.d/apache2 reload
        /etc/init.d/nginx reload

        # backup
        rm -rf ${home}/tmp/*
        mkdir ${home}/virtualhost
        mv /etc/nginx/sites-available/${domain} ${home}/virtalhosts/${domain}-nginx
        mv /etc/apache2/sites-available/${domain} ${home}/virtalhosts/${domain}-apache2
        tar zcf ${backup_path}/${user}.tar.gz ${home}

        # user and group removing
        userdel -rf ${user}
        groupdel ${user}

        ;;
    *)
        echo "Use: ./hosting-user.sh {create|ban|unban|delete} \$user \$domain"
        ;;
esac
