#!/usr/bin/env bash

sudo su

#####  VARIABLES  ########################
MYSQL_ROOT_PASSWORD=rootpass
APACHE_DOC_ROOT=html

#####  GENERAL UTILITIES  ################
echo "Installing general utilities"
yum -y install mlocate wget vim tree net-tools

#####  APACHE  ###########################
echo "Installing Apache"
yum -y install httpd
systemctl enable httpd
systemctl start httpd
echo "Configuring Apache"

# Disable Sendfile. Bug in Virtualbox.
sed -i "s/EnableSendfile on/EnableSendfile Off/g" /etc/httpd/conf/httpd.conf

# Create Document root in shared folder
if ! [ -d /vagrant/$APACHE_DOC_ROOT ]; then
  mkdir /vagrant/$APACHE_DOC_ROOT
fi
if ! [ -L /var/www/html ]; then
  rm -rf /var/www/html
  ln -fs /vagrant/$APACHE_DOC_ROOT /var/www/html
fi

# Disable SE Linux
setenforce 0

# Allow traffic through firewall
systemctl start firewalld
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --zone=public --add-service=https --permanent 
firewall-cmd --reload

# Restart Apache
apachectl restart

#####  PHP 7 #############################
echo "Installing PHP and PHP extensions"
yum -y install epel-release
rpm -Uvh http://rpms.remirepo.net/enterprise/remi-release-7.rpm
yum-config-manager --enable remi-php71
yum -y install php php-mbstring php-mcrypt php-mysqlnd php-gd php-fpm php-xml php-soap php-xmlrpc 
curl -s https://packagecloud.io/install/repositories/phalcon/stable/script.rpm.sh | sudo bash
# yum install php70u-phalcon

echo "Configuring PHP"
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php.ini 
sed -i "s/memory_limit = 128M/memory_limit = 256M /g" /etc/php.ini

echo "Installing Composer"
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

#####  MARIA DB  #########################
echo "Installing MariaDB"
yum -y install mariadb-server
systemctl enable mariadb
systemctl start mariadb

MYSQL_ROOT_PASSWORD=rootpass
mysqladmin -u root password "$MYSQL_ROOT_PASSWORD"

echo "Configuring MySQL - Secure Installation"
yum -y install expect 
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root:\"
send \"$MYSQL_ROOT_PASSWORD\r\"
expect \"Change the root password?:\"
send \"n\r\" 
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
echo "$SECURE_MYSQL" 

#####  PHPMYADMIN  #######################
echo "Installing phpMyAdmin"
yum -y install phpmyadmin
sed -i 's/Allow from 127.0.0.1/Allow from All/g' /etc/httpd/conf.d/phpMyAdmin.conf
sed -i '17i\       Require all granted' /etc/httpd/conf.d/phpMyAdmin.conf
apachectl restart