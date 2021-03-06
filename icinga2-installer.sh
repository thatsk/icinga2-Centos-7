#!/bin/bash
## Icinga2 centos Auto Installer
## This Installer works with Centos 7 /RHEL 7 only .
read -p "Please ensure that you added your hostname in hosts file also added using hostname command (hostname set-hostname <FQDN> ) , To continue press ENTER to Cancel CTRL + C"

HOST=`hostname -i`

if [ "$2" == apache ] ; then
clear
PASSWD=`openssl passwd -1 $1`
IP=`ifconfig enp3s0 | awk '{ print $2}' | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"`
##Icinga2 core installation
echo "Installing $(tput setaf 6)development Package$(tput sgr0) for Centos/RHEL7"
cd ~
yum install epel-release -y
yum groupinstall "Development Tools" -y
clear
echo "Installing $(tput setaf 6)Icinga2 Core$(tput sgr0) packages"
sleep 3s
rpm --import http://packages.icinga.org/icinga.key
curl -o /etc/yum.repos.d/ICINGA-release.repo http://packages.icinga.org/epel/ICINGA-release.repo
yum makecache
yum install icinga2  -y
yum install php vim php-gd php-intl php-ZendFramework php-ZendFramework-Db-Adapter-Pdo-Mysql -y
systemctl enable icinga2 
systemctl start icinga2 
icinga2 feature list 
systemctl enable icinga2
systemctl restart icinga2
##Installing Database
clear
echo "Installing $(tput setaf 6)MariaDB$(tput sgr0)"
sleep 3s
yum install mariadb-server mariadb -y
systemctl enable mariadb
systemctl start mariadb
echo -e "\n\n$1\n$1\n\n\nn\n\n " | mysql_secure_installation 2>/dev/null
echo "
[client]
user=root
password=$1" >> /etc/my.cnf
yum install icinga2-ido-mysql -y
echo "CREATE DATABASE icinga;" | mysql -u root
echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON icinga.* TO 'icinga'@'localhost' IDENTIFIED BY 'icinga';" | mysql -u root
mysql -u root icinga < /usr/share/icinga2-ido-mysql/schema/mysql.sql
icinga2 feature enable ido-mysql
systemctl restart icinga2
##Web configuration
clear
echo "Installing $(tput setaf 6)Apache$(tput sgr0) and $(tput setaf 6)Icinga2 Web$(tput sgr0)"
sleep 3s
yum install httpd nagios-plugins-all -y
systemctl enable httpd
systemctl start httpd
icinga2 feature enable command
systemctl restart icinga2
usermod -a -G icingacmd apache
#icingacli setup token create
#icingacli setup token show
git clone git://git.icinga.org/icingaweb2.git
cp -r icingaweb2 /usr/share/icingaweb2
cd /usr/share/icingaweb2
./bin/icingacli setup config webserver apache --document-root /usr/share/icingaweb2/public > /etc/httpd/conf.d/icingaweb2.conf
groupadd -r icingaweb2
usermod -a -G icingaweb2 apache
service httpd restart
./bin/icingacli setup config directory
./bin/icingacli setup token create
./bin/icingacli setup token show
##Final installation & Configuration
clear
echo "Final configuration$(tput setaf 5)Please wait...$(tput sgr0)"
sleep 4s
echo "CREATE DATABASE icingaweb2;" | mysql -u root
echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON icingaweb2.* TO 'icingaweb2'@'localhost' IDENTIFIED BY 'icingaweb2';" | mysql -u root
echo "Icinga2 Monitor Server  https://github.com/jamesarems" >> /etc/motd
mysql icingaweb2 < /usr/share/icingaweb2/etc/schema/mysql.schema.sql
echo "INSERT INTO icingaweb_user (name, active, password_hash) VALUES ('iadmin', 1, '$PASSWD');" | mysql icingaweb2

echo '[icingaweb2]
type                = "db"
db                  = "mysql"
host                = "localhost"
port                = "3306"
dbname              = "icingaweb2"
username            = "icingaweb2"
password            = "icingaweb2"


[icinga2]
type                = "db"
db                  = "mysql"
host                = "localhost"
port                = "3306"
dbname              = "icinga"
username            = "icinga"
password            = "icinga"
' > /etc/icingaweb2/resources.ini

echo '[logging]
log                 = "syslog"
level               = "ERROR"
application         = "icingaweb2"


[preferences]
type                = "db"
resource            = "icingaweb2"
' > /etc/icingaweb2/config.ini

echo '[icingaweb2]
backend             = "db"
resource            = "icingaweb2"
' > /etc/icingaweb2/authentication.ini

echo '[admins]
users               = "iadmin"
permissions         = "*"
' > /etc/icingaweb2/roles.ini
mkdir -p /etc/icingaweb2/modules/monitoring
echo '
[security]
protected_customvars = "*pw*,*pass*,community"
' > /etc/icingaweb2/modules/monitoring/config.ini

echo '
[icinga2]
type                = "ido"
resource            = "icinga2"
' > /etc/icingaweb2/modules/monitoring/backends.ini

echo '
[icinga2]
transport           = "local"
path                = "/var/run/icinga2/cmd/icinga2.cmd"
' > /etc/icingaweb2/modules/monitoring/commandtransports.ini




clear
echo "**********************************************************"
echo "**********************************************************"
echo "Icinga Web 2 token id:"
./bin/icingacli setup token show
echo "        Setup URL: http://yourIP/icingaweb2"
echo "        Username : iadmin"
echo "        Password : $1 "
echo "     NOTE : Enable monitor and document plugin"
echo "***********************************************************"
echo "***********************************************************"

echo "$(tput setaf 1)Cleaning installer from your system$(tput sgr0)"
find / -name icinga2-installer.sh -exec rm -f {} \;

elif [ "$2" == nginx ]; then
echo "Currently icinga2 with nginx under development . Please install using apache"

else 
echo " $(tput setaf 1)Wrong Key stroke$(tput sgr0) , Please put correct value and try again or read documentation"
fi
