require 'test_helper'
require 'rack/test'
require 'test/unit'

require 'mocha'
require 'webmock'


require 'smart_proxy_ipam/netbox/netbox_api'

ENV['RACK_ENV'] = 'test'



class NetBoxApiTest < ::Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::NetBox::Api.new
  end

  def test_get_subnet
      fixture_get_subnet = fixture('get_subnet.json')
      stub_request(:get, "https://bam.example.com/Services/REST/v1/getIPRangedByIP?address=10.100.39.0&containerId=100881&type=IP4Network").
        with(
          headers: {
            'Authorization' => 'Token: 0000000000000000000000000000000000000000',
            'Content-Type' => 'application/json'
          }
        ).
        to_return(status: 200, body: fixture_get_subnet)
  end

end
