#!/bin/bash
OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_PORT="8069"
IS_ENTERPRISE="False"   # Set this to True if you want to install the Odoo enterprise version!
OE_SUPERADMIN="admin"   # set the superadmin password
OE_CONFIG="/etc/${OE_USER}/${OE_USER}.conf"
DBUSER="${DBUSER:-odoo}"
DBPASSWORD="${DBPASSWORD:-odoo1234}"
#[ -z "$DBHOST" ] && read -p 'DB HOST: ' DBHOST
DBHOST=opt2pnryjwq699.cwwvrr2acdyz.eu-west-1.rds.amazonaws.com
DBPORT="${DBPORT:-5432}"

apt-get update -y
apt-get install python3-pip gdebi nginx libsasl2-dev python-dev libldap2-dev libssl-dev -y

### Installing Odoo
echo -e "----- Installing Odoo ------\n"
wget -O - https://nightly.odoo.com/odoo.key | apt-key add -
echo "deb http://nightly.odoo.com/11.0/nightly/deb/ ./" >> /etc/apt/sources.list.d/odoo.list
apt-get update -y && apt-get install odoo -y

echo -e "----- Removing Local Install of Postgres ------\n"
### Removing Postgres
service odoo stop
apt-get autoremove postgresql -y
service postgresql stop
apt-get update -y

###  WKHTMLTOPDF download links
WKHTMLTOX_X64=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.xenial_amd64.deb
WKHTMLTOX_X32=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.xenial_i386.deb

### Create the home directory if it does not exist
if [ ! -d ${OE_HOME} ]; then
    echo -e "Creating directory \"$OE_HOME\""
    su root -c "mkdir -p $OE_HOME"
    chown $OE_USER:$OE_USER $OE_HOME
fi

### Install Python Dependencies
pip3 install vobject qrcode num2words phonenumbers pyldap

echo -e "----- Installing nodeJS NPM -----\n"
apt-get install nodejs npm -y

### Install Wkhtmltopdf
echo -e "----- Install wkhtml -----\n"
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

echo -e "----- Updating Odoo config file -----\n"
>  /etc/odoo/odoo.conf
su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> ${OE_CONFIG}"
su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> ${OE_CONFIG}"
su root -c "printf 'db_host = ${DBHOST}\n' >> ${OE_CONFIG}"
su root -c "printf 'db_port = ${DBPORT}\n' >> ${OE_CONFIG}"
su root -c "printf 'db_user = ${DBUSER}\n' >> ${OE_CONFIG}"
su root -c "printf 'db_password = ${DBPASSWORD}\n' >> ${OE_CONFIG}"
su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> ${OE_CONFIG}"
su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_USER}-server.log\n' >> ${OE_CONFIG}"

if [ $IS_ENTERPRISE = "True" ]; then
    su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,/usr/lib/python3/dist-packages/odoo/addons,${OE_HOME}/custom/addons\n' >> ${OE_CONFIG}"
else
    su root -c "printf 'addons_path=/usr/lib/python3/dist-packages/odoo/addons,${OE_HOME}/custom/addons\n' >> ${OE_CONFIG}"
fi

echo -e "----- Starting Odoo Service ------\n"
service odoo start
service nginx start
