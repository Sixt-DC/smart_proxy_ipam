require 'sinatra'
require 'smart_proxy_ipam/ipam'
require 'smart_proxy_ipam/ipam_main'
require 'smart_proxy_ipam/netbox/netbox_client'
require 'smart_proxy_ipam/netbox/netbox_helper'

# TODO: Refactor later to handle multiple IPAM providers. For now, it is
# just NetBox that is supported
module Proxy::Netbox
  class Api < ::Sinatra::Base
    include ::Proxy::Log
    helpers ::Proxy::Helpers
    helpers NetboxHelper

    def provider
      @provider ||= begin
                     NetboxClient.new
                    end
    end

    # Gets the next available IP address based on a given subnet
    #
    # Inputs:   address:   Network address of the subnet(e.g. 100.55.55.0)
    #           prefix:    Network prefix(e.g. 24)
    #
    # Returns: Hash with next available IP address in "data", or hash with "message" containing
    #          error message from NetBox.
    #
    # Response if success:
    #   {"code": 200, "success": true, "data": "100.55.55.3", "time": 0.012}
    get '/subnet/:address/:prefix/next_ip' do
      content_type :json

      validate_required_params!([:address, :prefix, :mac], params)
      cidr = validate_cidr!(params[:address], params[:prefix])

      begin
        mac = params[:mac]
        group = params[:group]

        subnet = provider.get_subnet(cidr)
        check_subnet_exists!(subnet)

        provider.get_next_ip(subnet['data']['id'], mac, group, cidr).to_json
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET
        logger.debug(errors[:no_connection])
        raise
      end
    end


    # Returns an array of subnets from External IPAM matching the given subnet.
    #
    # Params:  1. subnet:           The IPv4 or IPv6 subnet CIDR. (Examples: IPv4 - "100.10.10.0/24",
    #                               IPv6 - "2001:db8:abcd:12::/124")
    #          2. group(optional):  The name of the External IPAM group containing the subnet.
    #
    # Returns: A subnet on success, or a hash with an "error" key on failure.
    #
    # Responses from Proxy plugin:
    #   Response if subnet(s) exists:
    #     {"data": {"subnet": "44.44.44.0", "description": "", "mask":"29"}}
    #   Response if subnet not exists:
    #     {"error": "No subnets found"}
    #   Response if can't connect to External IPAM server
    #     {"error": "Unable to connect to External IPAM server"}
    get '/subnet/:address/:prefix' do
      content_type :json

      validate_required_params!([:address, :prefix], params)
      cidr = validate_cidr!(params[:address], params[:prefix])

      subnet = begin
                 provider.get_subnet(cidr)
               rescue Errno::ECONNREFUSED, Errno::ECONNRESET
                 logger.debug(errors[:no_connection])
                 raise
               end

      status 404 unless subnet
      subnet.to_json
    end

    # Get a list of groups from External IPAM. A group is analagous to a 'section' in phpIPAM, and
    # is a logical grouping of subnets/ips.
    #
    # Params: None
    #
    # Returns: An array of groups on success, or a hash with a "error" key
    #          containing error on failure.
    #
    # Responses from Proxy plugin:
    #   Response if success:
    #     {"data": [
    #       {name":"Test Group","description": "A Test Group"},
    #       {name":"Awesome Group","description": "A totally awesome Group"}
    #     ]}
    #   Response if no groups exist:
    #     {"data": []}
    #   Response if groups are not supported:
    #     {"error": "Groups are not supported"}
    #   Response if can't connect to External IPAM server
    #     {"error": "Unable to connect to External IPAM server"}
    get '/groups' do
      content_type :json
      return {:error => "Groups are not supported"}.to_json
    end

    # Get a group from External IPAM. A group is analagous to a 'section' in phpIPAM, and
    # is a logical grouping of subnets/ips.
    #
    # Params: group: The name of the External IPAM group
    #
    # Returns: An External IPAM group on success, or a hash with an "error" key on failure.
    #
    # Responses from Proxy plugin:
    #   Response if success:
    #     {"data": {"name":"Awesome Section", "description": "Awesome Section"}}
    #   Response if group doesn't exist:
    #     {"error": "Not found"}
    #   Response if groups are not supported:
    #     {"error": "Groups are not supported"}
    #   Response if can't connect to External IPAM server
    #     {"error": "Unable to connect to External IPAM server"}
    get '/groups/:group' do
      content_type :json
      return {:error => "Groups are not supported"}.to_json
    end

    # Get a list of subnets for given external ipam section/group
    #
    # Input: section_name(string). The name of the external ipam section/group
    # Returns: Array of subnets(as json) in "data" key on success, hash with error otherwise
    # Examples:
    #   Response if success:
    #     {
    #       "code":200,
    #       "success":true,
    #       "data":[
    #         {
    #             "id":"24",
    #             "subnet":"100.10.10.0",
    #             "mask":"24",
    #             "sectionId":"10",
    #             "description":"wrgwgwefwefw",
    #             "linked_subnet":null,
    #             "firewallAddressObject":null,
    #             "vrfId":"0",
    #             "masterSubnetId":"0",
    #             "allowRequests":"0",
    #             "vlanId":"0",
    #             "showName":"0",
    #             "device":"0",
    #             "permissions":"[]",
    #             "pingSubnet":"0",
    #             "discoverSubnet":"0",
    #             "DNSrecursive":"0",
    #             "DNSrecords":"0",
    #             "nameserverId":"0",
    #             "scanAgent":"0",
    #             "isFolder":"0",
    #             "isFull":"0",
    #             "tag":"2",
    #             "threshold":"0",
    #             "location":"0",
    #             "editDate":null,
    #             "lastScan":null,
    #             "lastDiscovery":null,
    #             "usage":{
    #               "used":"0",
    #               "maxhosts":"254",
    #               "freehosts":"254",
    #               "freehosts_percent":100,
    #               "Offline_percent":0,
    #               "Used_percent":0,
    #               "Reserved_percent":0,
    #               "DHCP_percent":0
    #             }
    #         }
    #       ],
    #       "time":0.012
    #     }
    #   Response if :error =>
    #     {"error":"Unable to connect to External IPAM server"}
    get '/groups/:group/subnets' do
      content_type :json

      validate_required_params!([:group], params)

      begin
        section = provider.get_section(params[:group])
        halt 404, {:error => errors[:no_section]}.to_json unless section

        provider.get_subnets(section['id'].to_s, false).to_json
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET
        logger.debug(errors[:no_connection])
        raise
      end
    end

    # Checks whether an IP address has already been taken in external ipam.
    #
    # Params: 1. address:   The network address of the IPv4 or IPv6 subnet.
    #         2. prefix:    The subnet prefix(e.g. 24)
    #         3. ip:        IP address to be queried
    #
    # Returns: JSON object with 'exists' field being either true or false
    #
    # Example:
    #   Response if exists:
    #     {"ip":"100.20.20.18","exists":true}
    #   Response if not exists:
    #     {"ip":"100.20.20.18","exists":false}
    get '/subnet/:address/:prefix/:ip' do
      content_type :json

      validate_required_params!([:address, :prefix, :ip], params)
      ip = validate_ip!(params[:ip])
      cidr = validate_cidr!(params[:address], params[:prefix])
      validate_ip_in_cidr!(ip, cidr)

      begin
        subnet = provider.get_subnet(cidr)
        check_subnet_exists!(subnet)

        unless provider.ip_exists?(ip, subnet['data']['id'])
          halt 404, {error: "IP #{ip} was not found in subnet #{cidr}"}.to_json
        end
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET
        logger.debug(errors[:no_connection])
        raise
      end

      {ip: ip}.to_json
    end

    # Adds an IP address to the specified subnet
    #
    # Params: 1. address:   The network address of the IPv4 or IPv6 subnet.
    #         2. prefix:    The subnet prefix(e.g. 24)
    #         3. ip:        IP address to be added
    #
    # Returns: Hash with "message" on success, or hash with "error"
    #
    # Examples:
    #   Response if success:
    #     IPv4: {"message":"IP 100.10.10.123 added to subnet 100.10.10.0/24 successfully."}
    #     IPv6: {"message":"IP 2001:db8:abcd:12::3 added to subnet 2001:db8:abcd:12::/124 successfully."}
    #   Response if :error =>
    #     {"error":"The specified subnet does not exist in NetBox."}
    post '/subnet/:address/:prefix/:ip' do
      content_type :json

      validate_required_params!([:address, :ip, :prefix], params)
      ip = validate_ip!(params[:ip])
      cidr = validate_cidr!(params[:address], params[:prefix])
      validate_ip_in_cidr!(ip, cidr)

      begin
        section_name = params[:group]

        subnet = provider.get_subnet(cidr)
        check_subnet_exists!(subnet)

        add_ip = provider.add_ip_to_subnet(ip, subnet['data']['id'], 'Address auto added by Foreman')
        halt 500, add_ip.to_json if add_ip
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET
        logger.debug(errors[:no_connection])
        raise
      end

      status 201
      {ip: ip}.to_json
    end

    # Deletes IP address from a given subnet
    #
    # Params: 1. address:   The network address of the IPv4 or IPv6 subnet.
    #         2. prefix:    The subnet prefix(e.g. 24)
    #         3. ip:        IP address to be deleted
    #
    # Returns: JSON object
    # Example:
    #   Response if success:
    #     HTTP 204 No Content
    #   Response if :error =>
    #     {"code": 404, "success": 0, "message": "Address does not exist", "time": 0.008}
    delete '/subnet/:address/:prefix/:ip' do
      content_type :json

      validate_required_params!([:address, :prefix, :ip], params)
      ip = validate_ip!(params[:ip])
      cidr = validate_cidr!(params[:address], params[:prefix])
      validate_ip_in_cidr!(ip, cidr)

      begin
        section_name = params[:group]

        subnet = provider.get_subnet(cidr, section_name)
        check_subnet_exists!(subnet)

        delete_ip = provider.delete_ip_from_subnet(ip, subnet['data']['id'])
        halt 500, delete_ip.to_json if delete_ip
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET
        logger.debug(errors[:no_connection])
        raise
      end

      status 204
      nil
    end

    # Checks whether a subnet exists in a specific section.
    #
    # Params: 1. address:   The network address of the IPv4 or IPv6 subnet.
    #         2. prefix:    The subnet prefix(e.g. 24)
    #         3. group:     The name of the section
    #
    # Returns: JSON object with 'data' field is exists, otherwise field with 'error'
    #
    # Example:
    #   Response if exists:
    #     {"code":200,"success":true,"data":{"id":"147","subnet":"172.55.55.0","mask":"29","sectionId":"84","description":null,"linked_subnet":null,"firewallAddressObject":null,"vrfId":"0","masterSubnetId":"0","allowRequests":"0","vlanId":"0","showName":"0","device":"0","permissions":"[]","pingSubnet":"0","discoverSubnet":"0","resolveDNS":"0","DNSrecursive":"0","DNSrecords":"0","nameserverId":"0","scanAgent":"0","customer_id":null,"isFolder":"0","isFull":"0","tag":"2","threshold":"0","location":"0","editDate":null,"lastScan":null,"lastDiscovery":null,"calculation":{"Type":"IPv4","IP address":"\/","Network":"172.55.55.0","Broadcast":"172.55.55.7","Subnet bitmask":"29","Subnet netmask":"255.255.255.248","Subnet wildcard":"0.0.0.7","Min host IP":"172.55.55.1","Max host IP":"172.55.55.6","Number of hosts":"6","Subnet Class":false}},"time":0.009}
    #   Response if not exists:
    #     {"code":404,"error":"No subnet 172.66.66.0/29 found in section :group"}
    get '/group/:group/subnet/:address/:prefix' do
      content_type :json

      validate_required_params!([:address, :prefix, :group], params)
      cidr = validate_cidr!(params[:address], params[:prefix])

      subnet = begin
                 provider.get_subnet_by_section(cidr, params[:group])
               rescue Errno::ECONNREFUSED, Errno::ECONNRESET
                 logger.debug(errors[:no_connection])
                 raise
               end

      status 404 unless subnet
      subnet.to_json
    end
  end
end
