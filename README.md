# chef-zabbix

Library for integrating Chef and Zabbix. Provides a wrapper client that can call to Chef with [ridley](https://github.com/berkshelf/ridley) and to Zabbix with [zabbixapi](https://github.com/express42/zabbixapi).

[YARDoc available at rubydoc.info](http://www.rubydoc.info/github/atheiman/chef-zabbix).

> Currently only Zabbix server 2.2 is supported.

## Installation

Install the gem from GitHub.

## Usage

```ruby
require 'chef/zabbix'

# initialize the client that will communicate with the Zabbix and Chef apis
client = Chef::Zabbix.new({
  zabbix_url: 'http://zabbix.domain.net/api/api_jsonrpc.php',
  zabbix_user: 'someuser',
  zabbix_password: '5omeP@ssword'
})

# convert a chef node name to a zabbix host (represented as a hash returned from zabbixapi client)
client.chef_node_to_zabbix_host('my-chef-node')
#=> {"hostid"=>"1234",
#     "host"=>"node.domain.net",
#     "name"=>"node visible name", # alias for "host" if no visible name set
#     "groups"=>
#      [{"groupid"=>"5", "name"=>"Discovered hosts"},
#       {"groupid"=>"38", "name"=>"All Hosts"}],
#     "parentTemplates"=>
#      [{"templateid"=>"13160", "host"=>"My Linux Template"}],
#     "interfaces"=>[{"ip"=>"10.190.158.48"}]}

# convert a zabbix host id to a chef node (represented as a Ridley::NodeObject)
node = client.zabbix_host_to_chef_node(1234)
#=> #<Ridley::NodeObject chef_id:some-chef-node, attributes:#<VariaModel::Attributes ...
node.chef_attributes['ipaddress']
#=> "12.23.34.45"
node.run_list
#=> ["role[base_os]", "recipe[some_cookbook::some_recipe]"]
node.chef_environment
#=> "some_environment"
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/atheiman/chef-zabbix.

