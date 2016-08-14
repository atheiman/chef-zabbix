require 'chef/zabbix/version'
require 'ridley'
# 'zabbixapi' required dynamically

Ridley::Logging.logger.level = Logger.const_get 'ERROR' # get rid of Celluloid::TaskFiber warnings

class Chef
  class Zabbix
    # Initialize a new client that can communicate with Zabbix and Chef
    #
    # @param opts [Hash] Options to initialize the client with
    # @option opts [String] :zabbix_url _required_ Zabbix server api url
    # @option opts [String] :zabbix_user _required_ Zabbix api username
    # @option opts [String] :zabbix_password _required_ Zabbix api password
    # @option opts [String] :zabbix_http_user Zabbix api username for basic_auth
    #   (defaults to zabbix_user if needed and not provided)
    # @option opts [String] :zabbix_http_password Zabbix api password for basic_auth
    #   (defaults to zabbix_password if needed and not provided)
    # @option opts [String] :zabbix_version Zabbix server version (ex: 2.2, 2.2.5)
    # @note Only Zabbix server version 2.2 is currently supported (others may work)
    # @option opts [String] :chef_config Override the path to a knife.rb or client.rb
    #   (passed to Ridley.from_chef_config)
    #
    # @example
    #   initialize(
    #     zabbix_url: 'http://zabbix.domain.net/api/api_jsonrpc.php',
    #     zabbix_user: 'myusername',
    #     zabbix_password: 'mypassword',
    #     zabbix_http_user: 'myhttpusername',
    #     zabbix_http_password: 'myhttppassword',
    #     zabbix_version: '2.2',
    #     chef_config: '~/.chef/my_secondary_knife.rb',
    #   )
    def initialize(opts)
      # store all options as instance vars
      # ensure each required option is provided
      %i(zabbix_url zabbix_user zabbix_password).each do |opt|
        raise "Missing required option '#{opt}' from options hash." unless opts[opt]
        instance_variable_set("@#{opt}", opts[opt])
      end
    end

    # Validate the Zabbix version
    def zabbix_version
      # default the zabbix server version
      @zabbix_version = '2.2' unless defined? @zabbix_version
      # validate zabbix server version if provided
      unless @zabbix_version =~ /^\d+\.\d+(\.\d+)?$/
        raise "Could not determine Zabbix server version"
      end
      # TODO: log a warning if zabbix_version is not 2.2(.x)
      @zabbix_version
    end

    # Method to access a Ridley client (initialize it if necessary)
    #
    # @param chef_config [String] Override the path to a knife.rb or client.rb
    # @return [Ridley::Client]
    def ridley(chef_config=nil)
      @ridley if defined? @ridley
      if chef_config
        @ridley = Ridley.from_chef_config(File.expand_path(chef_config))
      else
        @ridley = Ridley.from_chef_config
      end
    end

    # Method to access a zabbixapi client (initialize it if necessary)
    #
    # @return [ZabbixApi]
    def zabbix
      @zabbix if defined? @zabbix
      require_zabbixapi
      begin
        @zabbix = ZabbixApi.connect(
          url: @zabbix_url,
          user: @zabbix_user,
          password: @zabbix_password
        )
      rescue
        @zabbix = ZabbixApi.connect(
          url: @zabbix_url,
          user: @zabbix_user,
          password: @zabbix_password,
          http_user: @zabbix_http_user || @zabbix_user,
          http_password: @zabbix_http_password || @zabbix_password
        )
      end
    end

    # Require the correct version of the zabbixapi gem based on the zabbix server version
    #
    # @return [Boolean] Returns true if `zabbixapi` gem was loaded and false if the gem was already
    #   loaded
    def require_zabbixapi
      version_components = zabbix_version.split('.').map { |n| n.to_i }
      major = version_components[0]
      minor = version_components[1]
      constraint = "~> #{major}.#{minor}.0"
      begin
        gem 'zabbixapi', constraint
        require 'zabbixapi'
      rescue
        raise "Could not load zabbixapi gem with version constraint '#{constraint}'"
      end
    end

    # Wrapper function for the host.get Zabbix api method that returns commonly used zabbix attrs
    #
    # @param search [Hash] Zabbix search passed into the `search` parameter of the host.get method
    # @return [Array<Hash>] Array of hosts represented as hashes with the following keys:
    #   `'groups'` (`Array<Hash>`),
    #   `'host'` (`String`),
    #   `'hostid'` (`String`),
    #   `'interfaces'` (`Array<Hash>`),
    #   `'name'` (`String`),
    #   `'parentTemplates'` (`Array<Hash>`)
    # @see https://www.zabbix.com/documentation/2.2/manual/api/reference/host/object Zabbix API Host
    #   object reference
    # @see https://www.zabbix.com/documentation/2.2/manual/api/reference/host/get Zabbix API
    #   host.get method reference
    #
    # @example Search by 'Host name' (`host` field)
    #   zabbix_host_get(name: 'some-host.domain.net')
    #   #=> [{"hostid"=>"12345",
    #   #     "host"=>"some-host.domain.net",
    #   #     "groups"=>
    #   #      [{"groupid"=>"5", "name"=>"Discovered hosts"},
    #   #       {"groupid"=>"38", "name"=>"All Hosts"}],
    #   #     "parentTemplates"=>
    #   #      [{"templateid"=>"23456", "host"=>"Template OS Linux"}],
    #   #     "interfaces"=>[{"ip"=>"12.23.34.45"}]}]
    # @example Search by 'IP address'
    #   zabbix_host_get(ip: '12.23.34.45')
    #   #=> [{"hostid"=>"12345",
    #   #     ...
    # @example Search by 'Visible name' (`name` field)
    #   zabbix_host_get(name: 'My Favorite Host')
    #   #=> [{"hostid"=>"12345",
    #   #     ...
    def zabbix_host_get(search)
      zabbix.query(
        method: 'host.get',
        params: {
          # TODO: parameterize this
          search: search,
          output: %w(hostid host name),
          selectGroups: %w(groupId name),
          selectInterfaces: ['ip'],
          selectParentTemplates: %w(templateid host)
        }
      )
    end

    # Find a Zabbix host from a Chef node name
    #
    # @param node_name [String] Chef node name
    # @return [Hash] Zabbix host
    # @see #zabbix_host_get Keys in the returned Zabbix host hash
    # @note Raises an error if Zabbix host cannot be reliably determined from Chef node data
    #
    # @example
    #   chef_node_to_zabbix_host('my-node')
    #   #=> {"hostid"=>"12345",
    #   #    ...
    def chef_node_to_zabbix_host(node_name)
      node = ridley.node.find(node_name)

      raise "Could not find Chef node '#{node_name}'" unless node

      # an ordering of zabbix searches to find a host based on chef attributes
      # TODO: parameterize this
      searches = [
        { name: node.name },
        { ip: node.chef_attributes['ipaddress'] },
        { host: node.chef_attributes['fqdn'] },
        { host: node.chef_attributes['hostname'] }
      ]

      # try each of the searches
      searches.each do |search|
        hosts = zabbix_host_get(search)
        # if exactly one node is returned we can be confident its the correct node
        return hosts[0] if hosts.length == 1
      end

      raise "Could not reliably determine Zabbix host with searches #{searches.join(', ')}"
    end

    # Get a list of Zabbix hosts from a chef search
    #
    # @param chef_search [String] Chef node search query
    # @return [Array<Hash>] Zabbix hosts
    # @see zabbix_host_get Keys in the returned Zabbix host hash
    #
    # @example
    #   chef_search_to_zabbix_hosts('chef_environment:*some_env*')
    #   #=> [{"hostid"=>"12345",
    #   #     ...
    def chef_search_to_zabbix_hosts(chef_search)
      nodes = ridley.partial_search(:node, chef_search)
      raise "No nodes returned by chef search '#{chef_search}'" if nodes.empty?

      # get the hosts from zabbix
      hosts = []
      nodes.each { |node| hosts << chef_node_to_zabbix_host(node.name)}
      hosts
    end

    # Find a Chef node from a Zabbix host id
    # @param hostid [String, Integer] Zabbix host id
    # @param partial_search [Array<String>] Limit the attributes to be returned by specifying them
    #   in dotted hash notation
    # @return Ridley::NodeObject
    # @note NodeObjects returned from `partial_search` are not fully populated, call
    #   `NodeObject#reload` to get all of the node's data from the Chef server
    # @note Raises an error if Chef node cannot be reliably determined from Zabbix host data
    #
    # @example
    #   node = client.zabbix_host_to_chef_node('12019')
    #   #=> #<Ridley::NodeObject chef_id:some-node, attributes:#<VariaModel::Attributes automatic=#<Hashie::Mash...>
    #   node.chef_attributes['kernel']['release']
    #   #=> "2.6.32-504.8.1.el6.x86_64"
    #   node.run_list
    #   #=> ["role[some_role]", "recipe[some_cookbook::some_recipe]"]
    #   node.chef_environment
    #   #=> "some_environment"
    #
    # @example
    #   node = client.zabbix_host_to_chef_node('12019', ['kernel.release'])
    #   #=> #<Ridley::NodeObject chef_id:some-node, attributes:#<VariaModel::Attributes automatic=#<Hashie::Mash...>
    #   node.chef_attributes['kernel']['release']
    #   #=> "2.6.32-504.8.1.el6.x86_64"
    #   # only ['cloud'], ['fqdn'], ['ipaddress'], and attributes specifically requested in the
    #   # partial_search Array will be returned
    #   node.chef_attributes.keys
    #   #=> ["cloud", "fqdn", "ipaddress", "kernel"]
    #   node.chef_attributes['kernel'].keys
    #   #=> ["release"]
    #   # even the run list and environment are not returned
    #   node.run_list
    #   #=> []
    #   node.chef_environment
    #   #=> "_default"
    #   # call NodeObject#reload to get all of the node's data from the Chef server
    #   node.reload
    #   #=> #<Ridley::NodeObject chef_id:some-node, attributes:#<VariaModel::Attributes automatic=#<Hashie::Mash...>
    #   node.chef_attributes['kernel'].keys
    #   #=> ["name", "release", "version", "machine", "os", "modules"]
    #   node.chef_attributes['kernel']['version']
    #   #=> "#1 SMP Fri Dec 19 12:09:25 EST 2014"
    #   node.run_list
    #   #=> ["role[some_role]", "recipe[some_cookbook::some_recipe]"]
    #   node.chef_environment
    #   #=> "some_environment"
    def zabbix_host_to_chef_node(hostid, partial_search=[])
      hosts = zabbix.query(
        method: 'host.get',
        params: {
          hostids: hostid.to_s,
          output: %w(host name),
          selectInterfaces: ['ip'],
        }
      )
      raise "Could not find Zabbix host with id '#{hostid}'" unless hosts.length == 1
      host = hosts[0]

      # build an array of chef searches to try
      searches = ["name:#{host['name']}"]
      # add searches for each ip addr on the zabbix host
      host['interfaces'].map { |iface| iface['ip'] }.compact.each do |ip|
        searches << "ipaddress:#{ip}"
      end
      searches << "fqdn:#{host['host']}"
      searches << "hostname:#{host['host']}"

      # try each of the searches
      searches.each do |search|
        nodes = []
        if partial_search.empty?
          nodes = ridley.search(:node, search)
        else
          nodes = ridley.partial_search(:node, search, partial_search)
        end
        # if exactly one node is returned we can be confident its the correct node
        return nodes[0] if nodes.length == 1
      end

      raise "Could not reliably determine Chef node with searches #{searches.join(', ')}"
    end
  end
end
