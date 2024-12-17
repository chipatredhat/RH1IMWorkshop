#!/bin/sh
source ./RH1Vars

# Install ansible-core if it's not already installed
[[ $(command -v ansible-playbook) ]] || sudo dnf -y install ansible-core

# Install git if it's not already installed
[[ $(command -v git) ]] || sudo dnf -y install git

mkdir $HOME/${WS_DIR}
cd $HOME/${WS_DIR}

# clone the repos
for i in ${REPOS} ; do git clone https://github.com/${i} ; done

# Get the user API token:
# Put together based on Ansible instructions at https://access.redhat.com/solutions/7013662
[[ -z "{OFFLINE_TOKEN}" ]] && echo -e "\n\nGet an offline API token from https://access.redhat.com/management/api\n" && read -p "What is your offline token? " OFFLINE_TOKEN

# Get the registry username and password
if [ -z "{REGISTRY_PASS}" ]
echo -e "\n\nRegistry Service Accounts can be created at: https://access.redhat.com/terms-based-registry\n"
read -p "What is your Registry Account/Service name? " REGISTRY_USERNAME
read -p "What is your Registry Account/Service password? " REGISTRY_PASS
fi

# Get the AAP instance to use
[[ -z "${AAP_HOSTNAME}" ]] && echo -e "\n\n" && read -p "What is the servername for your AAP instance? " AAP_HOSTNAME

# Get the server hostname
[[ -z "${SERVER}" ]] && echo -e "\n\n" && read -p "What is the host name for your build/web/gitea server? " SERVER

# Get the server username
[[ -z "${SERVER_USER}" ]] && echo -e "\n\n" && read -p "What is the username for your build/web/gitea server? " SERVER_USER

# Get the gitea username
[[ -z "${GITEA_USER}" ]] && echo -e "\n\n" && read -p "What is the username for your gitea instance? " GITEA_USER

cd $HOME/${WS_DIR}/rh1-image-mode

# Configure ansible.cfg and demo-setup-vars.yml with the gathered variables:
sed -i "s/YOURTOKENHERE/${OFFLINE_TOKEN}/" ansible.cfg
sed -i "s/aap.rh-lab.labs/${AAP_HOSTNAME}/g" demo-setup/demo-setup-vars.yml
sed -i "s/rhel9-server.rh-lab.labs/${SERVER}/g" demo-setup/demo-setup-vars.yml
sed -i "s/sysadmin/${SERVER_USER}/g" demo-setup/demo-setup-vars.yml demo-setup/demo-setup-vars.yml
sed -i "s/^redhat_registry_username.*/& ${REGISTRY_USERNAME}/" demo-setup/demo-setup-vars.yml
sed -i "s/^redhat_registry_password.*/& ${REGISTRY_PASS}/" demo-setup/demo-setup-vars.yml
sed -i "s/^automation_hub_token.*/& ${OFFLINE_TOKEN}/" demo-setup/demo-setup-vars.yml
sed -i "s/^gitea_username.*/gitea_username: ${GITEA_USER}/" demo-setup/demo-setup-vars.yml

# Clear any history that may contain sensitive information
history -c

cd $HOME/${WS_DIR}/rh1-image-mode

# Install ansible-galaxy requirements
ansible-galaxy install -r demo-setup/requirements.yml --force

clear

# Now run the playbook
echo -e "\n\nInstall will now proceed using admin as the username for your AAP install, and redhat for all passwords"
echo -e "If you need to change either of those, press Ctrl-C now to exit this script and change them in demo-setup/demo-setup-vars.yml"
echo -e "Then run ansible-playbook -i demo-setup/inventory demo-setup/configure-environment.yml\n"
read -n 1 -p " Do you wish to proceed? (Y/N) " RESPONSE
if [ "${RESPONSE^}" = "Y" ] ; then
ansible-playbook -i demo-setup/inventory demo-setup/configure-environment.yml
else
echo "Exiting...."
fi
