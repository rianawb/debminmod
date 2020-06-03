### Debminmod | TuxLite Fork Readme

Nginx + PHP7 fork. 

Removed Apache, Awstats.
PHP version is 7 (7.0.6).
Uses Dotdeb repository for Debian install.
Ubuntu is not tested currently.

Debminmod is a free collection of shell scripts for rapid deployment of
LNMP stacks (Linux, Nginx, MySQL and PHP) for Debian and
Ubuntu. 

Have you considered upgrading from shared hosting to a VPS or dedicated
server but held off by the costly control panel licenses, or the fear of
managing a Linux server? Now you can leave those worries behind!

Debminmod scripts automate configuration of servers for web hosting,
so your websites can be online within minutes! Ideal for those who
prefer hosting sites on their own server without resorting to expensive
and bloated control panels.

The following are installed:-

-   Nginx (Mainline)
-   MySQL, MariaDB or Percona
-   php7.2-FPM + commonly used PHP modules
-   Postfix mail server (securely configured to be outgoing only)
-   Varnish cache (optional)

For more detailed explanation on the installation, usage and script features, 
kindly refer to these links:-

[Installation](http://tuxlite.com/installation/)

[Script features](http://tuxlite.com/script-details/)

[Download](http://tuxlite.com/download/)

### Quick Install (Git)

    # Install git & tools
    apt-get install git mc screen zip unzip -y
    
    # Use screen for uninterrupted flow
    screen
    
    # Clone Debminmod
    git clone https://github.com/rianawb/debminmod.git
    cd debminmod
    
    # Edit options to enter server IP, MySQL password etc.
    nano options.conf
    # Save file after changes
    
    # Make all scripts executable.
    chmod 700 *.sh
    chmod 700 options.conf
    
    # Install LAMP or LNMP stack.
    ./install.sh
    
    # Add a new Linux user and add domains to the user.
    adduser johndoe
    ./domain.sh add johndoe yourdomain.com
    ./domain.sh add johndoe subdomain.yourdomain.com
    
    # Enable/disable public viewing of Adminer/phpMyAdmin
    ./domain.sh dbgui on
    ./domain.sh dbgui off

### Requirements

-   Supports Debian 8 and maybe Ubuntu 14, 15 (not tested).
-   A server with at least 80MB RAM. 256MB and above recommended.
-   Basic Linux knowledge. You will need know how to connect to your
    server remotely.
-   Basic text editor knowledge. For beginners, learning GNU nano is
    recommended.

If this is your first time with a Linux server, I suggest spending a day
reading the "getting started" tutorials in Linode Library.

### Why use Debminmod?

-   Debminmod LNMP stack configures Nginx and PHP with
    fastcgi (PHP-FPM). This gives much higher performance and lower memory
    consumption than the regular LNMP tutorials/guides using mod\_php.
-   Uses official distribution packages. You are not at the mercy of the
    script maintainer to keep your servers updated. All installed
    software are tuned, optimized and secured.
-   Minimal resource usage. Fresh install requires only 50-60MB RAM.
-   Free from unnecessary or custom changes to your server. Everything
    is configured according to Debian/Ubuntu standards.
-   Automatic virtualhost configuration with log rotation and phpMyAdmin for managing MySQL.
-   Varnish cache script included to turbo charge your websites.
-   Free and open source! Coded in a human readable manner and
    modular, making custom modifications extremely easy.
