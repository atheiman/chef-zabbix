#!/bin/bash

bundle
echo "before_script.sh pwd: $(pwd)"
bundle exec ./.travis/create_zabbix_objects.rb
