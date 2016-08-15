# chef-zabbix

Library for integrating Chef and Zabbix. Provides a wrapper client that can call to Chef with [ridley](https://github.com/berkshelf/ridley) and to Zabbix with [zabbixapi](https://github.com/express42/zabbixapi).

[YARDoc available at rubydoc.info](http://www.rubydoc.info/github/atheiman/chef-zabbix).

> Currently only Zabbix server 2.2 is supported.

## Installation

Install the gem from GitHub.

## Usage

Initialize the client that can communicate with the Chef and Zabbix APIs:

```ruby
require 'chef_zabbix'

client = ChefZabbix.new(
  zabbix_url: 'http://zabbix.domain.net/api/api_jsonrpc.php',
  zabbix_user: 'someuser',
  zabbix_password: '5omeP@ssword'
)
```

Get information about the Zabbix host that relates to a Chef node name

```ruby
client.chef_node_to_zabbix_host('some-node')
#=> {"hostid"=>"12019",
#    "host"=>"some-node.domain.net",
#    "name"=>"Some Node",
#    "groups"=>
#     [{"groupid"=>"5", "name"=>"Host Group A"},
#      {"groupid"=>"38", "name"=>"Host Group B"}],
#    "parentTemplates"=>
#     [{"templateid"=>"13160", "host"=>"Base Linux Template"}],
#      {"templateid"=>"13784", "host"=>"Some Custom Template"}],
#    "interfaces"=>[{"ip"=>"10.190.12.148"}]}
```

Get an array of Zabbix hosts from a Chef node search query:

```ruby
client.chef_search_to_zabbix_hosts('chef_environment:some_env AND run_list:*some_cookbook*')
#=>  {"hostid"=>"13284",
#     "host"=>"node-1.domain.net",
#     "name"=>"Node 1",
#     "groups"=>
#      [{"groupid"=>"5", "name"=>"Host Group A"},
#       {"groupid"=>"185", "name"=>"Host Group C"}],
#     "parentTemplates"=>
#      [{"templateid"=>"13160", "host"=>"Base Linux Template"}],
#       {"templateid"=>"14736", "host"=>"Another Custom Template"}],
#     "interfaces"=>[{"ip"=>"10.190.12.83"}]},
#    {"hostid"=>"12019",
#     ...
#     "interfaces"=>[{"ip"=>"10.190.12.148"}]}]
```

Get information about the Chef node that relates to a Zabbix host id:

```ruby
node = client.zabbix_host_to_chef_node(12019)
node.name
#=> "some-node"
node.run_list
#=> ["role[some_role]", "recipe[some_cookbook::some_recipe]"]
node.chef_environment
#=> "some_env"
node.chef_attributes['ipaddress']
#=> "10.190.12.148"
node.chef_attributes['kernel']
#=> {"name"=>"Linux",
#    "release"=>"2.6.32-504.8.1.el6.x86_64",
#    "version"=>"#1 SMP Fri Dec 19 12:09:25 EST 2014",
#    "machine"=>"x86_64",
#    "os"=>"GNU/Linux",
#    "modules"=>
#     {"8021q"=>{"size"=>"25527", "refcount"=>"0"},
#      "garp"=>{"size"=>"7152", "refcount"=>"1"},
#      ...
#      "dm_mod"=>{"size"=>"95622", "refcount"=>"32"}}}
```

Get information about the Chef node that relates to a Zabbix host id, but limit the response from
the Chef server using partial search:

```ruby
node = client.zabbix_host_to_chef_node(12019, ['kernel.release', 'memory.swap'])
node.name
#=> "some-node"
node.chef_attributes['kernel']['release']
#=> "2.6.32-504.8.1.el6.x86_64"
node.chef_attributes['memory']['swap']
#=> {"cached"=>"72kB", "total"=>"2097148kB", "free"=>"2096556kB"}

# Note that Ridley::NodeObjects returned from partial_search have only a very small amount of Chef
# node data. That's why partial_search lightens the load on the Chef server (and returns nodes much
# faster). For more information, read about partial search in the Chef documentation and the Ridley
# readme.
node.chef_attributes['kernel'].keys
#=> ["release"] # only the 'release' key is available in the 'kernel' attribute
node.chef_attributes['memory'].keys
#=> ["swap"] # only the 'swap' key is available in the 'memory' attribute
# Ridley::NodeObjects returned from partial_search don't even have run list or environment data
node.run_list
#=> []
node.chef_environment
#=> "_default"

# Call Ridley::NodeObject#reload to get all the data about a node from the Chef server
node.reload

# Now all node data is accessible as expected
node.chef_attributes['kernel'].keys
#=> ["name", "release", "version", "machine", "os", "modules"] # all kernel data is available
pp(node.chef_attributes['memory'].keys)
#=> ["swap", "total", "free", "buffers", "cached", ...] # all memory data is available
node.run_list
#=> ["role[some_role]", "recipe[some_cookbook::some_recipe]"]
node.chef_environment
#=> "some_env"
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/atheiman/chef-zabbix.

