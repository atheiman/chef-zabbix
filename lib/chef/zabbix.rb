require 'chef/zabbix/version'
require 'ridley'

module Chef
  class Zabbix
    def initialize(opts)
      # store all options as instance vars
      # ensure each required option is provided
      %i(zabbix_url zabbix_user zabbix_password).each do |opt|
        raise "Missing required option '#{opt}' from options hash." unless opts[opt]
        instance_variable_set("@#{opt}", opts[opt])
      end
    end

    def zabbix_version
      # default the zabbix server version
      @zabbix_version = '2.2' unless defined? @zabbix_version
      # validate zabbix server version if provided
      unless @zabbix_version =~ /^\d+\.\d+(\.\d+)?$/
        raise "Could not determine Zabbix server version"
      end
      @zabbix_version
    end

    # returns a ridley chef api client
    def ridley(chef_config=nil)
      @ridley if defined? @ridley
      # store a ridley client
      if chef_config
        # load a specific knife.rb or client.rb
        @ridley = Ridley.from_chef_config(chef_config)
      else
        # look in the default locations for a chef config file
        @ridley = Ridley.from_chef_config
      end
    end

    # return the zabbix api client (initialize it if necessary)
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

    # require the correct version of zabbixapi gem based on the zabbix server version
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

    # a generic host.get api call wrapper that returns commonly used zabbix attrs
    def zabbix_host_get(search)
      zabbix.query(
        method: 'host.get',
        params: {
          search: search,
          output: %w(hostid host),
          selectGroups: %w(groupId name),
          selectInterfaces: ['ip'],
          selectParentTemplates: %w(templateid host)
        }
      )
    end

    # returns a zabbix host using the given chef node name
    # example zabbix host returned:
    #   {"hostid"=>"1234",
    #    "host"=>"node.domain.net",
    #    "name"=>"node visible name", # alias for "host" if no visible name set
    #    "groups"=>
    #     [{"groupid"=>"5", "name"=>"Discovered hosts"},
    #      {"groupid"=>"38", "name"=>"All Hosts"}],
    #    "parentTemplates"=>
    #     [{"templateid"=>"13160", "host"=>"My Linux Template"}],
    #    "interfaces"=>[{"ip"=>"10.190.158.48"}]}
    def chef_node_to_zabbix_host(node_name)
      node_name = node_name.name if node_name.respond_to? :name
      # get the chef node information
      node = ridley.node.find(node_name)

      raise "Could not find Chef node '#{node_name}'" unless node

      # an ordering of zabbix searches to find a host based on chef attributes
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

      raise "Could not find Zabbix host with searches #{searches.join(', ')}"
    end

    # returns a simple ridley node object from the given zabbix host id
    # partial_search is passed into ridley's partial_search function to return non-default
    #   attributes in the node object
    def zabbix_host_to_chef_node(hostid, partial_search=[])
      hostid = hostid['hostid'] if hostid['hostid']
      hosts = zabbix.query(
        method: 'host.get',
        params: {
          hostids: hostid.to_s,
          output: %w(host name),
          selectInterfaces: ['ip'],
        }
      )
      raise "Could not find Zabbix host with id '#{hostid}'" unless hosts.length == 0
      host = hosts[0]

      # build an array of chef searches to try
      searches = ["name:#{name}"]
      # add searches for each ip addr on the zabbix host
      host['interfaces'].map { |iface| iface['ip'] }.compact.each do |ip|
        searches << "ipaddress:#{ip}"
      end
      searches << "fqdn:#{host}"
      searches << "hostname:#{host}"

      # try each of the searches
      searches.each do |search|
        nodes = ridley.partial_search(:node, search, partial_search)
        # if exactly one node is returned we can be confident its the correct node
        return nodes[0] if nodes.length == 1
      end

      raise "Could not find Chef node with searches #{searches.join(', ')}"
    end
  end
end
