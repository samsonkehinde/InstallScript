#!/bin/bash
OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_PORT="8069"
OE_VERSION="11.0"
# Set this to True if you want to install the Odoo enterprise version!
IS_ENTERPRISE="False"
# set the superadmin password
OE_SUPERADMIN="admin"
OE_CONFIG="${OE_HOME}/${OE_USER}.conf"

### Create the home directory if it does not exist
if [ ! -d $OE_HOME ]; then
    echo -e "Creating directory \"$OE_HOME\""
    su $OE_USER -c "mkdir -p $OE_HOME"
fi

###  WKHTMLTOPDF download links
WKHTMLTOX_X64=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.xenial_amd64.deb
WKHTMLTOX_X32=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.xenial_i386.deb

### Update Server
echo -e "----- Update Server -----\n"
# universe package is for Ubuntu 18.x
add-apt-repository universe
# libpng12-0 dependency for wkhtmltopdf
add-apt-repository "deb http://mirrors.kernel.org/ubuntu/ xenial main"
wget -O - https://nightly.odoo.com/odoo.key | apt-key add -
echo "deb http://nightly.odoo.com/$OE_VERSION/nightly/deb/ ./" >> /etc/apt/sources.list.d/odoo.list
apt-get update && apt-get upgrade -y

### Install Dependencies
echo -e "----- Installing Dependencies -----\n"
apt-get install git python3 python3-pip build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng12-0 gdebi odoo -y

### Install Python Dependencies
pip3 install vobject qrcode pyldap num2words

echo -e "----- Installing nodeJS NPM and rtlcss for LTR support -----\n"
apt-get install nodejs npm -y
npm install -g rtlcss

### Install Wkhtmltopdf
echo -e "----- Install wkhtml and place shortcuts on correct place for ODOO 13 -----\n"
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

### Remove Postgres
service odoo stop
apt-get autoremove postgresql -y
service postgresql stop
apt-get update -y

### Create Addons folder
su $OE_USER -c "mkdir -p $OE_HOME/addons"
mv  "/usr/lib/python3/dist-packages/odoo/addons" $OE_HOME/addons

### Install ODOO
echo -e "----- Install Enterprise Repository -----\n"
if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise install!
    echo -e "\n--- Create symlink for node"
    ln -s /usr/bin/nodejs /usr/bin/node
    su $OE_USER -c "mkdir -p $OE_HOME/enterprise/addons"

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

    echo -e "----- Installing Enterprise specific libraries -----\n"
    pip3 install num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL
    npm install -g less less-plugin-clean-css
fi

echo -e "----- Create module directories -----\n"
su $OE_USER -c "mkdir -p $OE_HOME/custom/addons"
su $OE_USER -c "mkdir -p $OE_HOME/addons"

echo -e "----- Creating Odoo Config file -----\n"
touch ${OE_CONFIG}
echo -e "----- Creating server config file -----\n"
su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> ${OE_CONFIG}"
su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> ${OE_CONFIG}"
su root -c "printf 'db_host = ${DBHOST}\n' >> ${OE_CONFIG}"
su root -c "printf 'db_port = ${DBPORT}\n' >> ${OE_CONFIG}"
su root -c "printf 'db_user = ${DBUSER}\n' >> ${OE_CONFIG}"
su root -c "printf 'db_password = ${DBPASSWORD}\n' >> ${OE_CONFIG}"
su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> ${OE_CONFIG}"
su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_USER}-server.log\n' >> ${OE_CONFIG}"

if [ $IS_ENTERPRISE = "True" ]; then
    su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME}/addons,${OE_HOME}/custom/addons\n' >> ${OE_CONFIG}"
else
    su root -c "printf 'addons_path=${OE_HOME}/addons,${OE_HOME}/custom/addons\n' >> ${OE_CONFIG}"
fi

chown $OE_USER:$OE_USER ${OE_CONFIG}
chmod 640 ${OE_CONFIG}

echo -e "----- Starting Odoo Service ------\n"
service odoo start
