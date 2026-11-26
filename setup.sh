#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root." >&2
  echo "Try: curl -s <script_url> | sudo bash -s -- ${*:-<yournewdomain>}" >&2
  echo "  or: sudo bash setup.sh ${*:-<yournewdomain>}" >&2
  exit 1
fi

apt -y update
apt-get install -y apache2 certbot python3-certbot-apache unzip

# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <yournewdomain>"
  exit 1
fi

# Assign the first argument to the variable
export yournewdomain="$1"
echo "[+] The domain has been set to: $yournewdomain"

echo "Fetching the current external IP..."
# Get the external IP of the current machine
current_ip=$(curl -s ifconfig.me)

echo "Current external IP: $current_ip"
# Get the resolved IP of the provided domain from google dns server
domain_ip=$(dig +short @8.8.8.8 "$yournewdomain" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)

# Check if the domain resolved successfully
if [ -z "$domain_ip" ]; then
  echo "Error: Unable to resolve domain IP for $yournewdomain."
  exit 1
fi

echo "Resolved IP for the domain $domain: $domain_ip"

# Compare the two IPs
if [ "$current_ip" == "$domain_ip" ]; then
  echo "[+] The domain IP ($domain_ip) matches the current external IP ($current_ip)."
else
  echo "[x] The domain IP ($domain_ip) does NOT match the current external IP ($current_ip)."
  exit 1
fi

echo "Setting up Apache config"

# Apache Config
mkdir -p /var/www/${yournewdomain} /var/www/${yournewdomain}/html /var/www/${yournewdomain}/logs
cd /etc/apache2/sites-available
cp 000-default.conf 001-${yournewdomain}.conf
sed -i -e "/ServerAdmin */a ServerName ${yournewdomain}" /etc/apache2/sites-available/001-${yournewdomain}.conf
sed -i -e "/DocumentRoot */a ServerAlias www.${yournewdomain}" /etc/apache2/sites-available/001-${yournewdomain}.conf
sed -i -e "s/\/var\/www\/html/\/var\/www\/${yournewdomain}\/html/g" /etc/apache2/sites-available/001-${yournewdomain}.conf
sed -i 's,${APACHE_LOG_DIR},/var/www/'"${yournewdomain}"'/logs,g' /etc/apache2/sites-available/001-${yournewdomain}.conf

# Create backup
cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.bk
sed -i "/<Directory \/var\/www\/>/a Options FollowSymLinks\n\tAllowOverride None\n\tRequire all granted\n</Directory>\n\n<Directory \/var\/www\/${yournewdomain}\/html>" /etc/apache2/apache2.conf
# Disable directory listing: remove "Indexes" from the Options of every /var/www directory
sed -i '/<Directory \/var\/www[^>]*>/,/<\/Directory>/ s/^\(\s*Options\s\+\)Indexes\s\+/\1/' /etc/apache2/apache2.conf

echo "Restarting Apache Service"
# Config site and Restart Apache service
apachectl configtest
a2ensite 001-${yournewdomain}.conf
service apache2 restart

echo "[+] Done! html folder on /var/www/${yournewdomain}/html, logs on /var/www/${yournewdomain}/logs"

echo "[!] Activate HTTPS for the new domain"

# Activate HTTPS for the new domain.
certbot --agree-tos --register-unsafely-without-email -d ${yournewdomain}
echo "[!] Downloading website template"
# optional download fake website
wget https://github.com/bott0n/https_website_setup/raw/refs/heads/main/financial.zip -O /tmp/financial.zip
unzip /tmp/financial.zip -d /tmp/
mv /tmp/financial/* /var/www/${yournewdomain}/html/

echo "[+] Finished!!!"
