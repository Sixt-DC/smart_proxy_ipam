
require 'smart_proxy_for_testing'
require 'smart_proxy_ipam/netbox/netbox_api'

require 'test_helper'
require 'rack/test'
require 'test/unit'

#require 'mocha'
#require 'mocha/setup'
#require 'webmock'
#require 'webmock/test_unit'


ENV['RACK_ENV'] = 'test'


class NetBoxApiTest < ::Test::Unit::TestCase
  include Rack::Test::Methods

  def app
     Proxy::Netbox::Api.new
  end

  #def setup
#    @api_url = 'https://netbox.example.com'
    #@api_token = '0000000000000000000000000000000000000000'
  #  Proxy::Netbox::Plugin.load_test_settings(:url => @salt_rest_api, :token => @api_token)
  #end



  def test_get_groups_not_supported
    get '/groups'
    assert last_response.ok?
    assert_equal '{"error":"Groups are not supported"}', last_response.body
  end

  def test_get_group_not_supported
    get '/groups/1'
    assert last_response.ok?
    assert_equal '{"error":"Groups are not supported"}', last_response.body
  end

  def test_get_group_subnet_not_supported
    get '/groups/1/subnets'
    assert last_response.ok?
    assert_equal '{"error":"Groups are not supported"}', last_response.body
  end

  def test_get_subnet
    get '/subnet/10.100.60.0/24/10.100.60.1'
    #assert last_response.ok?
    assert_equal '{"data":{"subnet":"10.100.60.0","mask":"24","description":"Foreman Netz","id":3}}', last_response.body
  end

end
