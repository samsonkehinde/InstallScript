wget -O - https://nightly.odoo.com/odoo.key | apt-key add -
echo "deb http://nightly.odoo.com/11.0/nightly/deb/ ./" >> /etc/apt/sources.list.d/odoo.list
apt-get update -y && apt-get install python3-pip gdebi-core nginx libsasl2-dev python-dev libldap2-dev libssl-dev -y
wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.xenial_amd64.deb
gdebi --n `basename wkhtmltox_0.12.5-1.xenial_amd64.deb`
### Remove Postgres
service odoo stop
apt-get autoremove postgresql -y
service postgresql stop
apt-get update -y
service odoo start
