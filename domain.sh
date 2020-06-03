#!/bin/bash
######################################################################
# TuxLite virtualhost script                                         #
# Easily add/remove domains or subdomains                            #
# Configures logrotate and php7.2-FPM                         #
# Enables/disables Adminer/phpMyAdmin  #
######################################################################

source ./options.conf

# Seconds to wait before removing a domain/virtualhost
REMOVE_DOMAIN_TIMER=10

# Check domain to see if it contains invalid characters. Option = yes|no.
DOMAIN_CHECK_VALIDITY="yes"

#### First initialize some static variables ####

# Specify path to database management tool
if [ $DB_GUI -eq 1 ]; then
    DB_GUI_PATH="/usr/local/share/phpmyadmin/"
else
    DB_GUI_PATH="/usr/local/share/adminer/"
fi


# Logrotate Postrotate for Nginx
POSTROTATE_CMD='[ ! -f /var/run/nginx.pid ] || kill -USR1 `cat /var/run/nginx.pid`'

# Variables for Adminer|phpMyAdmin functions
# The path to find for Adminer|phpMyAdmin symbolic links
PUBLIC_HTML_PATH="/home/*/domains/*/public_html"
VHOST_PATH="/home/*/domains/*"

#### Functions Begin ####

function initialize_variables {

    # Initialize variables based on user input. For add/rem functions displayed by the menu
    DOMAINS_FOLDER="/home/$DOMAIN_OWNER/domains"
    DOMAIN_PATH="/home/$DOMAIN_OWNER/domains/$DOMAIN"
    GIT_PATH="/home/$DOMAIN_OWNER/repos/$DOMAIN.git"

    DOMAIN_CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"
    DOMAIN_ENABLED_PATH="/etc/nginx/sites-enabled/$DOMAIN"

    # Name of the logrotate file
    LOGROTATE_FILE="domain-$DOMAIN"

}


function reload_webserver {

    service nginx reload

} # End function reload_webserver


function php_fpm_add_user {

    # Copy over FPM template for this Linux user if it doesn't exist
    if [ ! -e /etc/php/7.2/fpm/pool.d/$DOMAIN_OWNER.conf ]; then
        cp /etc/php/7.2/fpm/pool.d/{www.conf,$DOMAIN_OWNER.conf}

        # Change pool user, group and socket to the domain owner
        sed -i 's/^\[www\]$/\['${DOMAIN_OWNER}'\]/' /etc/php/7.2/fpm/pool.d/$DOMAIN_OWNER.conf
        sed -i 's/^listen =.*/listen = \/var\/run\/php\/php7.2-fpm-'${DOMAIN_OWNER}'.sock/' /etc/php/7.2/fpm/pool.d/$DOMAIN_OWNER.conf
        sed -i 's/^user = www-data$/user = '${DOMAIN_OWNER}'/' /etc/php/7.2/fpm/pool.d/$DOMAIN_OWNER.conf
        sed -i 's/^group = www-data$/group = '${DOMAIN_OWNER}'/' /etc/php/7.2/fpm/pool.d/$DOMAIN_OWNER.conf
        sed -i 's/^;listen.mode =.*/listen.mode = 0666/' /etc/php/7.2/fpm/pool.d/$DOMAIN_OWNER.conf

        sed -i 's/^;listen.owner =.*/listen.owner = nginx/' /etc/php/7.2/fpm/pool.d/$DOMAIN_OWNER.conf
        sed -i 's/^;listen.group =.*/listen.group = nginx/' /etc/php/7.2/fpm/pool.d/$DOMAIN_OWNER.conf

    fi

    service php7.2-fpm restart

} # End function php_fpm_add_user


function add_domain {

    # Create public_html and log directories for domain
    mkdir -p $DOMAIN_PATH/{logs,public_html}
    touch $DOMAIN_PATH/logs/{access.log,error.log}
    # Add htpasswd file
    htpasswd -b -c $DOMAIN_PATH/.htpasswd $DOMAIN_OWNER $DOMAIN_OWNER

    cat > $DOMAIN_PATH/public_html/index.html <<EOF
<html>
<head>
<title>$DOMAIN</title>
</head>
<body>
<h1>$DOMAIN</h1>
<p>Website is under construction.</p>
</body>
</html>
EOF

    # Set permissions
    chown $DOMAIN_OWNER:$DOMAIN_OWNER $DOMAINS_FOLDER
    chown -R $DOMAIN_OWNER:$DOMAIN_OWNER $DOMAIN_PATH
    # Allow execute permissions to group and other so that the webserver can serve files
    chmod 711 $DOMAINS_FOLDER
    chmod 711 $DOMAIN_PATH

    # Virtualhost entry
    # Nginx webserver. Use Nginx vHost config
    cat > $DOMAIN_CONFIG_PATH <<EOF
server {
        listen 80;
        #listen [::]:80 default ipv6only=on;

        server_name www.$DOMAIN $DOMAIN;
        root $DOMAIN_PATH/public_html;
        access_log $DOMAIN_PATH/logs/access.log combined buffer=256k flush=60m;
        error_log $DOMAIN_PATH/logs/error.log;

        index index.php index.html index.htm;
        error_page 404 /404.html;

        location / {
            try_files \$uri \$uri/ /index.php?\$args;
        }

    location ~* /(wp-login\.php) {
        limit_req zone=xwplogin burst=1 nodelay;
        limit_conn xwpconlimit 30;
        auth_basic "Private";
        auth_basic_user_file $DOMAIN_PATH/.htpasswd; 
        fastcgi_pass unix:/var/run/php/php7.2-fpm-$DOMAIN_OWNER.sock;
        include /etc/nginx/allphp.conf;
    }

    location ~* /(xmlrpc\.php) {
        limit_req zone=xwprpc burst=45 nodelay;
        #limit_conn xwpconlimit 30;
        fastcgi_pass unix:/var/run/php/php7.2-fpm-$DOMAIN_OWNER.sock;
        include /etc/nginx/allphp.conf;
    }

        # Pass PHP scripts to PHP-FPM
        location ~ \.php$ {
            fastcgi_pass unix:/var/run/php/php7.2-fpm-$DOMAIN_OWNER.sock;
            include /etc/nginx/allphp.conf;
        }

include /etc/nginx/secureloc.conf;
include /etc/nginx/staticfiles.conf;

}


server {
        listen 443 ssl http2;
        server_name www.$DOMAIN $DOMAIN;
        root $DOMAIN_PATH/public_html;
        access_log $DOMAIN_PATH/logs/access.log combined buffer=256k flush=60m;
        error_log $DOMAIN_PATH/logs/error.log;

        index index.php index.html index.htm;
        error_page 404 /404.html;

        # ssl conf
        
        ssl on;
        ssl_certificate /etc/ssl/localcerts/webserver.pem;
        ssl_certificate_key /etc/ssl/localcerts/webserver.key;

        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 60m;

        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;

        # mozilla recommended
          ssl_ciphers ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA:!CAMELLIA:!DES-CBC3-SHA;
          ssl_prefer_server_ciphers   on;
          #add_header Alternate-Protocol  443:npn-spdy/3;
          #add_header Strict-Transport-Security "max-age=31536000; includeSubdomains;";
          #add_header  X-Content-Type-Options "nosniff";
          #add_header X-Frame-Options DENY;
          #spdy_headers_comp 5;
          ssl_buffer_size 1400;
          ssl_session_tickets on;
          
          # enable ocsp stapling
          #resolver 8.8.8.8 8.8.4.4 valid=10m;
          #resolver_timeout 10s;
          #ssl_stapling on;
          #ssl_stapling_verify on;
          
        # ssl conf end

        location / {
            try_files \$uri \$uri/ /index.php?\$args;
        }

    location ~* /(wp-login\.php) {
        limit_req zone=xwplogin burst=1 nodelay;
        limit_conn xwpconlimit 30;
        auth_basic "Private";
        auth_basic_user_file $DOMAIN_PATH/.htpasswd; 
        fastcgi_pass unix:/var/run/php/php7.2-fpm-$DOMAIN_OWNER.sock;
        include /etc/nginx/allphp.conf;
    }

    location ~* /(xmlrpc\.php) {
        limit_req zone=xwprpc burst=45 nodelay;
        #limit_conn xwpconlimit 30;
        fastcgi_pass unix:/var/run/php/php7.2-fpm-$DOMAIN_OWNER.sock;
        include /etc/nginx/allphp.conf;
    }

        # Pass PHP scripts to PHP-FPM
        location ~ \.php$ {
            fastcgi_pass unix:/var/run/php/php7.2-fpm-$DOMAIN_OWNER.sock;
            include /etc/nginx/allphp.conf;
        }

include /etc/nginx/secureloc.conf;
include /etc/nginx/staticfiles.conf;

}
EOF



    # Add new logrotate entry for domain
    cat > /etc/logrotate.d/$LOGROTATE_FILE <<EOF
$DOMAIN_PATH/logs/*.log {
    daily
    missingok
    rotate 10
    compress
    delaycompress
    notifempty
    create 0660 $DOMAIN_OWNER $DOMAIN_OWNER
    sharedscripts
    prerotate

    endscript
    postrotate
        $POSTROTATE_CMD
    endscript
}
EOF

    # Enable domain from sites-available to sites-enabled
    ln -s $DOMAIN_CONFIG_PATH $DOMAIN_ENABLED_PATH

    # GIT
    if [ $GIT_ENABLE = 'yes' ]; then
        mkdir -p $GIT_PATH
        cd $GIT_PATH
        git init --bare
        cat > hooks/post-receive <<EOF
#!/bin/sh
    GIT_WORK_TREE=$DOMAIN_PATH git checkout -f
EOF
        chmod +x hooks/post-receive
        cd - &> /dev/null

        # Set permissions
        chown -R $DOMAIN_OWNER:$DOMAIN_OWNER $GIT_PATH
        echo -e "\033[35;1mSuccesfully Created git repository \033[0m"
        echo -e "\033[35;1mgit remote add web ssh://$DOMAIN_OWNER@$HOSTNAME_FQDN:$SSHD_PORT/$GIT_PATH \033[0m"
    fi


} # End function add_domain


function remove_domain {

    echo -e "\033[31;1mWARNING: This will permanently delete everything related to $DOMAIN\033[0m"
    echo -e "\033[31mIf you wish to stop it, press \033[1mCTRL+C\033[0m \033[31mto abort.\033[0m"
    sleep $REMOVE_DOMAIN_TIMER

    # First disable domain and reload webserver
    echo -e "* Disabling domain: \033[1m$DOMAIN\033[0m"
    sleep 1
    rm -rf $DOMAIN_ENABLED_PATH
    reload_webserver

    # Then delete all files and config files

    echo -e "* Removing domain files: \033[1m$DOMAIN_PATH\033[0m"
    sleep 1
    rm -rf $DOMAIN_PATH

    echo -e "* Removing vhost file: \033[1m$DOMAIN_CONFIG_PATH\033[0m"
    sleep 1
    rm -rf $DOMAIN_CONFIG_PATH

    echo -e "* Removing logrotate file: \033[1m/etc/logrotate.d/$LOGROTATE_FILE\033[0m"
    sleep 1
    rm -rf /etc/logrotate.d/$LOGROTATE_FILE

    echo -e "* Removing git repository: \033[1m$GIT_PATH\033[0m"
    sleep 1
    rm -rf $GIT_PATH

} # End function remove_domain


function check_domain_exists {

    # If virtualhost config exists in /sites-available or the vhost directory exists,
    # Return 0 if files exists, otherwise return 1
    if [ -e "$DOMAIN_CONFIG_PATH" ] || [ -e "$DOMAIN_PATH" ]; then
        return 0
    else
        return 1
    fi

} # End function check_domain_exists


function check_domain_valid {

    # Check if the domain entered is actually valid as a domain name
    # NOTE: to disable, set "DOMAIN_CHECK_VALIDITY" to "no" at the start of this script
    if [ "$DOMAIN_CHECK_VALIDITY" = "yes" ]; then
        if [[ "$DOMAIN" =~ [\~\!\@\#\$\%\^\&\*\(\)\_\+\=\{\}\|\\\;\:\'\"\<\>\?\,\/\[\]] ]]; then
            echo -e "\033[35;1mERROR: Domain check failed. Please enter a valid domain.\033[0m"
            echo -e "\033[35;1mERROR: If you are certain this domain is valid, then disable domain checking option at the beginning of the script.\033[0m"
            return 1
        else
            return 0
        fi
    else
    # If $DOMAIN_CHECK_VALIDITY is "no", simply exit
        return 0
    fi

} # End function check_domain_valid


function dbgui_on {

    # Search virtualhost directory to look for "dbgui". In case the user created a "dbgui" folder, we do not want to overwrite it.
    dbgui_folder=`find $PUBLIC_HTML_PATH -maxdepth 1 -name "dbgui" -print0 | xargs -0 -I path echo path | wc -l`

    # If no "dbgui" folders found, find all available public_html folders and create "dbgui" symbolic link to /usr/local/share/adminer|phpmyadmin
    if [ $dbgui_folder -eq 0 ]; then
        find $VHOST_PATH -maxdepth 1 -name "public_html" -type d | xargs -L1 -I path ln -sv $DB_GUI_PATH path/dbgui
        echo -e "\033[35;1mAdminer or phpMyAdmin enabled.\033[0m"
    else
        echo -e "\033[35;1mERROR: Failed to enable Adminer or phpMyAdmin for all domains. \033[0m"
        echo -e "\033[35;1mERROR: It is already enabled for at least 1 domain. \033[0m"
        echo -e "\033[35;1mERROR: Turn it off again before re-enabling. \033[0m"
        echo -e "\033[35;1mERROR: Also ensure that all your public_html(s) do not have a manually created \"dbgui\" folder. \033[0m"
    fi

} # End function dbgui_on


function dbgui_off {

    # Search virtualhost directory to look for "dbgui" symbolic links
    find $PUBLIC_HTML_PATH -maxdepth 1 -name "dbgui" -type l -print0 | xargs -0 -I path echo path > /tmp/dbgui.txt

    # Remove symbolic links
    while read LINE; do
        rm -rfv $LINE
    done < "/tmp/dbgui.txt"
    rm -rf /tmp/dbgui.txt

    echo -e "\033[35;1mAdminer or phpMyAdmin disabled. If \"removed\" messages do not appear, it has been previously disabled.\033[0m"

} # End function dbgui_off


#### Main program begins ####

# Show Menu
if [ ! -n "$1" ]; then
    echo ""
    echo -e "\033[35;1mSelect from the options below to use this script:- \033[0m"
    echo -n  "$0"
    echo -ne "\033[36m add user Domain.tld\033[0m"
    echo     " - Add specified domain to \"user's\" home directory. Log rotation will be configured."

    echo -n  "$0"
    echo -ne "\033[36m rem user Domain.tld\033[0m"
    echo     " - Remove everything for Domain.tld including stats and public_html. If necessary, backup domain files before executing!"

    echo -n  "$0"
    echo -ne "\033[36m dbgui on|off\033[0m"
    echo     " - Disable or enable public viewing of Adminer or phpMyAdmin."

    echo ""
    exit 0
fi
# End Show Menu


case $1 in
add)
    # Add domain for user
    # Check for required parameters
    if [ $# -ne 3 ]; then
        echo -e "\033[31;1mERROR: Please enter the required parameters.\033[0m"
        exit 1
    fi

    # Set up variables
    DOMAIN_OWNER=$2
    DOMAIN=$3
    initialize_variables

    # Check if user exists on system
    if [ ! -d /home/$DOMAIN_OWNER ]; then
        echo -e "\033[31;1mERROR: User \"$DOMAIN_OWNER\" does not exist on this system.\033[0m"
        echo -e " - \033[34mUse \033[1madduser\033[0m \033[34m to add the user to the system.\033[0m"
        echo -e " - \033[34mFor more information, please see \033[1mman adduser\033[0m"
        exit 1
    fi

    # Check if domain is valid
    check_domain_valid
    if [ $? -ne 0 ]; then
        exit 1
    fi

    # Check if domain config files exist
    check_domain_exists
    if [  $? -eq 0  ]; then
        echo -e "\033[31;1mERROR: $DOMAIN_CONFIG_PATH or $DOMAIN_PATH already exists. Please remove before proceeding.\033[0m"
        exit 1
    fi

    add_domain
    php_fpm_add_user
    reload_webserver
    echo -e "\033[35;1mSuccesfully added \"${DOMAIN}\" to user \"${DOMAIN_OWNER}\" \033[0m"
    echo -e "\033[35;1mYou can now upload your site to $DOMAIN_PATH/public_html.\033[0m"
    echo -e "\033[35;1mAdminer/phpMyAdmin is DISABLED by default. URL = http://$DOMAIN/dbgui.\033[0m"
    echo -e "\033[35;1mIf Varnish cache is enabled, please disable & enable it again to reconfigure this domain. \033[0m"
    ;;
rem)
    # Add domain for user
    # Check for required parameters
    if [ $# -ne 3 ]; then
        echo -e "\033[31;1mERROR: Please enter the required parameters.\033[0m"
        exit 1
    fi

    # Set up variables
    DOMAIN_OWNER=$2
    DOMAIN=$3
    initialize_variables

    # Check if user exists on system
    if [ ! -d /home/$DOMAIN_OWNER ]; then
        echo -e "\033[31;1mERROR: User \"$DOMAIN_OWNER\" does not exist on this system.\033[0m"
        exit 1
    fi

    # Check if domain config files exist
    check_domain_exists
    # If domain doesn't exist
    if [ $? -ne 0 ]; then
        echo -e "\033[31;1mERROR: $DOMAIN_CONFIG_PATH and/or $DOMAIN_PATH does not exist, exiting.\033[0m"
        echo -e " - \033[34;1mNOTE:\033[0m \033[34mThere may be files left over. Please check manually to ensure everything is deleted.\033[0m"
        exit 1
    fi

    remove_domain
    ;;
dbgui)
    if [ "$2" = "on" ]; then
        dbgui_on
    elif [ "$2" = "off" ]; then
        dbgui_off
    fi
    ;;
esac
