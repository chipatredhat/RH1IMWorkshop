#!/bin/sh
source ./RH1Vars

# What is the hostname to install AAP to:
[[ -z "${AAP_HOSTNAME}" ]] && echo -e "\n\n" && read -p "What is the host name for your AAP server? " AAP_HOSTNAME
sudo hostnamectl set-hostname ${AAP_HOSTNAME}
# Add hostname to /etc/hosts
echo "$(hostname -I) ${AAP_HOSTNAME}" | sudo tee -a /etc/hosts

# Get the credentials to register this system with RHSM and register it
[[ -z "${ORG}" ]] && echo -e "\n\n" && read -p "What is the organization or username for RHSM Registration? " ORG
[[ -z "${KEY}" ]] && echo -e "\n\n" && read -p "What is the password or activation key for RHSM Registration? " KEY
sudo subscription-manager register --org ${ORG} --activationkey ${KEY}

# Install ansible-core if it's not already installed
[[ $(command -v ansible-playbook) ]] || sudo dnf -y install ansible-core

# Setup the directories and files to install AAP from a bundle and configure the inventory file
[[ -z "${AAP_BUNDLE}" ]] && echo -e "\n\n" && read -p "What is the name of the containerized aap setup bundle? " AAP_BUNDLE
[[ -z "${AAP_DIR}" ]] && echo -e "\n\n" && read -p "What directory will we use to copy the AAP setup files to? " AAP_DIR
tar xzvf ${AAP_BUNDLE} -C ${AAP_DIR}
[[ -z "${AAP_MANIFEST}" ]] && echo -e "\n\n" && read -p "What is filename of your manifest? " AAP_MANIFEST
mv ${AAP_MANIFEST} ${AAP_DIR}
cd ${AAP_DIR}
mv inventory-growth inventory
sed -i "s/aap.example.org/${AAP_HOSTNAME}/g" inventory
sed -i "s/<set your own>/redhat/g" inventory
[[ -z "${SERVER_USER}" ]] && echo -e "\n\n" && read -p "What is the lab username? " SERVER_USER
sudo loginctl enable-linger ${SERVER_USER}
echo "bundle_install=true" >> inventory
echo "bundle_dir=${AAP_DIR}/bundle" >> inventory
echo "controller_license_file=${AAP_DIR}/${AAP_MANIFEST}" >> inventory
[[ -z "${ENVOY_HTTP_PORT}" ]] && echo -e "\n\n" && read -p "What http are you using for AAP? " ENVOY_HTTP_PORT
[[ -z "${ENVOY_HTTPS_PORT}" ]] && echo -e "\n\n" && read -p "What https are you using for AAP? " ENVOY_HTTPS_PORT
echo "envoy_http_port=${ENVOY_HTTP_PORT}" >> inventory
echo "envoy_https_port=${ENVOY_HTTPS_PORT}" >> inventory

# If we are using example.com, get the ssl files and install the CA rpm
if [ "${USE_EXAMPLE}" = "Y" ] ; then
curl -sO https://raw.githubusercontent.com/chipatredhat/ImageModeWorkshop/refs/heads/main/files/wildcard.example.com.crt
curl -sO https://raw.githubusercontent.com/chipatredhat/ImageModeWorkshop/refs/heads/main/files/wildcard.example.com.key
sudo dnf -y install https://github.com/chipatredhat/ImageModeWorkshop/raw/refs/heads/main/files/example.com-root-ca-20240701-1.noarch.rpm
fi

# Ensure the firewall ports are open for AAP
sudo firewall-cmd --add-port=8443/tcp --add-port=${ENVOY_HTTPS_PORT}/tcp --add-port=${ENVOY_HTTP_PORT}/tcp
sudo firewall-cmd --add-port=8443/tcp --add-port=${ENVOY_HTTPS_PORT}/tcp --add-port=${ENVOY_HTTP_PORT}/tcp --permanent
#echo "gateway_tls_cert=${PWD}/wildcard.example.com.crt" >> inventory
#echo "gateway_tls_key=${PWD}/wildcard.example.com.key" >> inventory

# Now run the playbook to install AAP
ansible-playbook -i inventory ansible.containerized_installer.install
