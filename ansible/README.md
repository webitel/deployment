# Webitel

## Install Ansible 2.10+ on Debian 12

Check Debian version

	lsb_release -d
	Description:    Debian GNU/Linux 12 (bookworm)

Install Ansible

	apt install git gnupg sudo ansible

Check Ansible version:

	ansible --version
    ansible [core 2.14.3]

## Run ansible playbook for webitel

Install Webitel:

	ansible-playbook -i hosts/localhost playbook.yml