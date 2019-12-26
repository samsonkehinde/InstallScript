#!/bin/bash
OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_PORT="8069"
OE_VERSION="13.0"
# Set this to True if you want to install the Odoo enterprise version!
IS_ENTERPRISE=false
# set the superadmin password
OE_SUPERADMIN="admin"
OE_CONFIG="/etc/odoo/${OE_USER}.conf"

###  WKHTMLTOPDF download links
WKHTMLTOX_X64=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.xenial_amd64.deb
WKHTMLTOX_X32=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.xenial_i386.deb

### Update Server
echo -e "\n---- Update Server ----"
# universe package is for Ubuntu 18.x
add-apt-repository universe
# libpng12-0 dependency for wkhtmltopdf
add-apt-repository "deb http://mirrors.kernel.org/ubuntu/ xenial main"
apt-get update
apt-get upgrade -y

### Install Dependencies
echo -e "\n--- Installing Python 3 + pip3 --"
apt-get install git python3 python3-pip build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng12-0 gdebi -y

echo -e "\n---- Installing nodeJS NPM and rtlcss for LTR support ----"
apt-get install nodejs npm -y
npm install -g rtlcss


### Install Wkhtmltopdf
echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 13 ----"
#pick up correct one from x64 & x32 versions:
if [ `uname -m` = "x86_64" ];then
    _url=$WKHTMLTOX_X64
else
    _url=$WKHTMLTOX_X32
fi
wget $_url
gdebi --n `basename $_url`
ln -s /usr/local/bin/wkhtmltopdf /usr/bin
ln -s /usr/local/bin/wkhtmltoimage /usr/bin

### Install ODOO
if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise install!
    echo -e "\n--- Create symlink for node"
    ln -s /usr/bin/nodejs /usr/bin/node
    su $OE_USER -c "mkdir $OE_HOME/enterprise"
    su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------WARNING------------------------------"
        echo "Your authentication with Github has failed! Please try again."
        printf "In order to clone and install the Odoo enterprise version you \nneed to be an offical Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.\n"
        echo "TIP: Press ctrl+c to stop this script."
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    done

    echo -e "\n---- Installing Enterprise specific libraries ----"
    pip3 install num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL
    npm install -g less less-plugin-clean-css
fi

echo -e "\n---- Create custom module directory ----"
su $OE_USER -c "mkdir $OE_HOME/custom"
su $OE_USER -c "mkdir $OE_HOME/custom/addons"

echo -e "---- Creating Odoo Config file -----"
touch ${OE_CONFIG}
echo -e "---- Creating server config file"
su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> ${OE_CONFIG}"
su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> ${OE_CONFIG}"
su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> ${OE_CONFIG}"
su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_USER}-server.log\n' >> ${OE_CONFIG}"

if [ $IS_ENTERPRISE = "True" ]; then
    su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME}/addons,${OE_HOME}/custom/addons\n' >> ${OE_CONFIG}"
else
    su root -c "printf 'addons_path=${OE_HOME}/addons,${OE_HOME}/custom/addons\n' >> ${OE_CONFIG}"
fi

chown $OE_USER:$OE_USER ${OE_CONFIG}
chmod 640 ${OE_CONFIG}

echo -e "----- Starting Odoo Service -----"
service odoo start
