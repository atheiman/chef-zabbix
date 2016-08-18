#!/usr/bin/env ruby

require 'zabbixapi'
require 'pp'

zbx = ZabbixApi.connect(
  url: 'http://localhost/zabbix/api_jsonrpc.php',
  user: 'Admin',
  password: 'zabbix'
)

puts 'Zabbix API info:'
pp(zbx.query(method: 'apiinfo.version'))

# ['Hostgroup A', 'Hostgroup B', 'Hostgroup C'].each do |name|
#   zbx.hostgroups.create(name: name)
# end

# [{host: 'template-a', name: 'Template A'},
#  {host: 'template-b', name: 'Template B'},
#  {host: 'template-c', name: 'Template C'}].each do |template|
#   zbx.templates.create(template)
# end

# [{host: 'host-a',
#   name:'Host A',
#   groups: [groupid: zbx.hostgroups.get_id(name: 'Hostgroup A')]},
#  {host: 'host-b',
#   name:'Host B',
#   groups: [groupid: zbx.hostgroups.get_id(name: 'Hostgroup B')]},
#  {host: 'host-c',
#   name:'Host C',
#   groups: [groupid: zbx.hostgroups.get_id(name: 'Hostgroup C')]},]

# zbx.templates.mass_add(
#   :hosts_id => [zbx.hosts.get_id(:host => "hostname")],
#   :templates_id => [111, 214]
# )
