require 'test/unit'
require 'mocha/setup'
require 'smart_proxy_for_testing'


def fixture_netbox(name)
  File.read(File.expand_path("../fixtures/netbox/#{name}", __FILE__))
end
