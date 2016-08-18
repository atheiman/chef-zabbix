#!/bin/bash

bundle
echo "before_script.sh pwd: $(pwd)"
bundle exec create_zabbix_objects.rb
bundle exec rspec
