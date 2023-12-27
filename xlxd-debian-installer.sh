#!/bin/bash
# A tool to install xlxd, your own D-Star Reflector.
# For more information, please visit: https://n5amd.com
#Lets begin-------------------------------------------------------------------------------------------------
WHO=$(whoami)
if [ "$WHO" != "root" ]
then
  echo ""
  echo "You Must be root to run this script!!"
  exit 0
fi
if [ ! -e "/etc/debian_version" ]
then
  echo ""
  echo "This script is only tested in Debian 9, 10, 11 and 12 and x64 cpu Arch. "
  exit 0
fi
DIRDIR=$(pwd)
LOCAL_IP=$(ip a | grep inet | grep "eth0\|en" | awk '{print $2}' | tr '/' ' ' | awk '{print $1}')
INFREF=https://n5amd.com/digital-radio-how-tos/create-xlx-xrf-d-star-reflector/
XLXDREPO=https://github.com/erstec/xlxd.git
XLXDBRANCH=dark-mode
DMRIDURL=http://xlxapi.rlx.lu/api/exportdmr.php
WEBDIR=/var/www/xlxd
XLXINSTDIR=/root/reflector-install-files/xlxd
DEP="git build-essential apache2 php libapache2-mod-php php7.0-mbstring"
DEP2="git build-essential apache2 php libapache2-mod-php php7.3-mbstring"
DEP3="git build-essential apache2 php libapache2-mod-php php7.4-mbstring"
DEP4="git build-essential apache2 php libapache2-mod-php php8.2-mbstring"
VERSION=$(sed 's/\..*//' /etc/debian_version)

echo ""
echo "XLX uses 3 digit numbers for its reflectors. For example: 032, 999, 099."
read -p "What 3 digit XRF number will you be using?  " XRFDIGIT
XRFNUM=XLX$XRFDIGIT
echo ""
# echo "--------------------------------------"
# read -p "What is the FQDN of the XLX Reflector dashboard? Example: xlx.domain.com.  " XLXDOMAIN
# echo ""
# echo "--------------------------------------"
# read -p "What E-Mail address can your users send questions to?  " EMAIL
# echo ""
# echo "--------------------------------------"
# read -p "What is the admins callsign?  " CALLSIGN
# echo ""
echo "--------------------------------------"
read -p "What is the IP address of AMBE server?  " AMBEIP
echo ""
echo "--------------------------------------"
echo ""
echo "------------------------------------------------------------------------------"
echo "Making install directories and installing dependicies...."
echo "------------------------------------------------------------------------------"
mkdir -p $XLXINSTDIR
mkdir -p $WEBDIR
apt-get update

# Make VERSION variable to be 9, 10, 11 or 12
if [ $VERSION = "bookworm/sid" ]
then
    VERSION=12
fi

# Hardcoded to Ubuntu 22
# VERSION=12

if [ $VERSION = 9 ]
then
    apt-get -y install $DEP
    a2enmod php7.0
elif [ $VERSION = 10 ]
then
    apt-get -y install $DEP2
elif [ $VERSION = 11 ]
then
    apt-get -y install $DEP3
elif [ $VERSION = 12 ]
then
    apt-get -y install $DEP4
else
    echo ""
    echo "This script is only tested in Debian 9/10/11/12 and x64 cpu Arch. "
    exit 0
fi

echo "------------------------------------------------------------------------------"
if [ -e $XLXINSTDIR/xlxd/src/xlxd ]
then
   echo ""
   echo "It looks like you have already compiled XLXD. If you want to install/complile xlxd again, delete the directory '/root/reflector-install-files/xlxd' and run this script again. "
   exit 0
else
   echo "Downloading and compiling xlxd... "
   echo "------------------------------------------------------------------------------"
   cd $XLXINSTDIR
   git clone -b $XLXDBRANCH $XLXDREPO
   cd $XLXINSTDIR/xlxd/src
   make clean
   make
   make install
fi
if [ -e $XLXINSTDIR/xlxd/src/xlxd ]
then
   echo ""
   echo ""
   echo "------------------------------------------------------------------------------"
   echo "It looks like everything compiled successfully. There is a 'xlxd' application file. "
else
   echo ""
   echo "UH OH!! I dont see the xlxd application file after attempting to compile."
   echo "The output above is the only indication as to why it might have failed.  "
   echo "Delete the directory '/root/reflector-install-files/xlxd' and run this script again. "
   echo ""
   exit 0
fi

echo "------------------------------------------------------------------------------"
echo "Getting the DMRID.dat file... "
echo "------------------------------------------------------------------------------"
wget -O /xlxd/dmrid.dat $DMRIDURL
echo "------------------------------------------------------------------------------"

echo "Copying web dashboard files... "
cp -R $XLXINSTDIR/xlxd/dashboard/* /var/www/xlxd/

echo "Copying dark mode web dashboard files... "
mkdir -p /var/www/newxlxd
cp -R $XLXINSTDIR/xlxd/dashboard2/* /var/www/newxlxd/

echo "Copying and adjusting the xlxd.service file... "
if [ -e "/etc/init.d/xlxd" ]
then
  echo ""
  echo "xlxd.service file in /etc/init.d/xlx already exists. "
  echo "Skipping the creation of the xlxd.service file. "
  echo ""
else
  cp $XLXINSTDIR/xlxd/scripts/xlxd /etc/init.d/xlxd
  sed -i "s/XLX999 192.168.1.240 127.0.0.1/$XRFNUM $LOCAL_IP $AMBEIP/g" /etc/init.d/xlxd
  update-rc.d xlxd defaults
fi

# Delaying startup time
# mv /etc/rc3.d/S01xlxd /etc/rc3.d/S10xlxd ##Disabling as its not really needed. 

# echo "Updating XLXD Config file... "
# XLXCONFIG=/var/www/xlxd/pgs/config.inc.php
# sed -i "s/your_email/$EMAIL/g" $XLXCONFIG
# sed -i "s/LX1IQ/$CALLSIGN/g" $XLXCONFIG
# sed -i "s/http:\/\/your_dashboard/http:\/\/$XLXDOMAIN/g" $XLXCONFIG
# sed -i "s/\/tmp\/callinghome.php/\/xlxd\/callinghome.php/g" $XLXCONFIG
# echo "Copying directives and reloading apache... "
echo "Set WWW folders permissions... "
# cp $DIRDIR/templates/apache.tbd.conf /etc/apache2/sites-available/$XLXDOMAIN.conf
# sed -i "s/apache.tbd/$XLXDOMAIN/g" /etc/apache2/sites-available/$XLXDOMAIN.conf
# sed -i "s/ysf-xlxd/xlxd/g" /etc/apache2/sites-available/$XLXDOMAIN.conf
chown -R www-data:www-data /var/www/xlxd/
chown -R www-data:www-data /var/www/newxlxd/
chown -R www-data:www-data /xlxd/

# a2ensite $XLXDOMAIN

echo "Starting XLXD... "
service xlxd start

echo "Stopping XLXD... "
service xlxd stop

# systemctl restart apache2

echo "------------------------------------------------------------------------------"
echo ""
echo ""
echo "******************************************************************************"
echo ""
echo ""
echo "XLXD is finished installing and ready to be used. Please read the following..."
echo ""
echo ""
echo "******************************************************************************"
echo ""
echo "You can make further customizations to the main config file $XLXCONFIG."
echo "Be sure to thank the creators of xlxd for the ability to spin up          "
echo "your very own D-Star reflector.                                           "
echo ""
echo "------------------------------------------------------------------------------"
