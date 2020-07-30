
require 'smart_proxy_ipam/phpipam/phpipam_api'

map '/ipam' do
  run Proxy::Netbox::Api
end
