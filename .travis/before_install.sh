#!/bin/bash

sudo wget http://repo.zabbix.com/zabbix/2.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_2.2-1+trusty_all.deb
sudo dpkg -i zabbix-release_2.2-1+trusty_all.deb
sudo apt-get -q update
sudo apt-get -qy install zabbix-server-mysql zabbix-frontend-php
