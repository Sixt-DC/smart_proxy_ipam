
require 'smart_proxy_ipam/phpipam/phpipam_api'
require 'smart_proxy_ipam/netbox/netbox_api'

map '/ipam' do
  run Proxy::Netbox::Api
end
