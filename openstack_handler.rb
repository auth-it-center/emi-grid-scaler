require 'rubygems'
require 'openstack'
require 'fog'
require 'retryable'
require 'excon'

class OpenstackHandler # the OS_handler will be per provider (may need vms in two different Openstacks)

  def initialize(debug=false, username='admin', tenant_name='admin', auth_url='unspecified', ip, api_key)
    @debug = debug
    @os_ip = ip
    @os_username = username
    @os_tenant_name = tenant_name
    @os_api_key = api_key
    if (auth_url == 'unspecified')
      @os_auth_url = "http://#{ip}:5000/v2.0/tokens"
    else
      @os_auth_url = "#{auth_url}tokens"
    end
    @openstack_vm_counter = 0
    # late binding

  end


  # Configuration instance variables and accessors
  @@DEFAULT_FLAVOR_ID = 3
  @@DEFAULT_HG_IMAGE_ID = 1
  @@DEFAULT_GR_IMAGE_ID = 1

  def debug=(debug_openstack)
    @@debug = debug_openstack
  end

  def debug
    @@debug
  end

  def flavor_id=(flavor_id)
    @@flavor_id = flavor_id
  end

  def flavor_id
    @@flavor_id
  end

  def image_id=(image_id)
    @@image_id = image_id
  end

  def image_id
    @@image_id
  end
  ###################################

  @@counter = 0
  
  @@os = nil
  @@allservers = []
  
  def self.counter
    return @@counter

  end


  def init_client
    Retryable.retryable(:tries => 5, :sleep => 2, :on => Fog::Errors::NotFound) do
      @compute = Fog::Compute.new({:provider => 'OpenStack',
                                   :openstack_api_key => @os_api_key,
                                   :openstack_username => @os_username,
                                   :openstack_auth_url => @os_auth_url,
                                   :openstack_tenant => @os_tenant_name})
    end
    @floating_ip_pools = []
    Retryable.retryable(:tries => 5, :sleep => 2, :on => Fog::Errors::NotFound) do
      @compute.list_address_pools.data[:body]['floating_ip_pools'].each do |pool|
        @floating_ip_pools << pool['name']
      end
    end
  end

  def get_current_vms
    #{"id"=>"fd02b58e-1cc5-45fc-b58b-e175642410d4", "links"=>[{"href"=>"http://172.16.8.150:8774/v2/969af8e3338c4f0a9f434d5a8941bcc2/servers/fd02b58e-1cc5-45fc-b58b-e175642410d4", "rel"=>"self"}, {"href"=>"http://172.16.8.150:8774/969af8e3338c4f0a9f434d5a8941bcc2/servers/fd02b58e-1cc5-45fc-b58b-e175642410d4", "rel"=>"bookmark"}], "name"=>"wn-golden-image-backup"}

    # {"server"=>{"status"=>"ACTIVE", "updated"=>"2015-01-23T09:16:19Z",
    # "hostId"=>"994913c99f9ec2ba255ff50826d5d61d602dfecbacc3af7f7438bda2",
    # "addresses"=>{"barney_net"=>[{"OS-EXT-IPS-MAC:mac_addr"=>"fa:16:3e:44:2c:a4",
    # "version"=>4, "addr"=>"192.168.100.6", "OS-EXT-IPS:type"=>"fixed"},
    # {"OS-EXT-IPS-MAC:mac_addr"=>"fa:16:3e:44:2c:a4", "version"=>4, "addr"=>"172.16.9.37",
    # "OS-EXT-IPS:type"=>"floating"}]},
    # "links"=>[{"href"=>"http://172.16.8.150:8774/v2/969af8e3338c4f0a9f434d5a8941bcc2/servers/fd02b58e-1cc5-45fc-b58b-e175642410d4",
    # "rel"=>"self"}, {"href"=>"http://172.16.8.150:8774/969af8e3338c4f0a9f434d5a8941bcc2/servers/fd02b58e-1cc5-45fc-b58b-e175642410d4",
    # "rel"=>"bookmark"}], "key_name"=>"steve", "image"=>{"id"=>"4b0ee0c4-3c67-48fc-b041-a97d855bc989",
    # "links"=>[{"href"=>"http://172.16.8.150:8774/969af8e3338c4f0a9f434d5a8941bcc2/images/4b0ee0c4-3c67-48fc-b041-a97d855bc989",
    # "rel"=>"bookmark"}]}, "OS-EXT-STS:task_state"=>nil, "OS-EXT-STS:vm_state"=>"active",
    # "OS-SRV-USG:launched_at"=>"2015-01-19T14:50:05.000000", "flavor"=>{"id"=>"3", "links"=>[{"href"=>"http://172.16.8.150:8774/969af8e3338c4f0a9f434d5a8941bcc2/flavors/3",
    # "rel"=>"bookmark"}]}, "id"=>"fd02b58e-1cc5-45fc-b58b-e175642410d4", "security_groups"=>[{"name"=>"default"}], "OS-SRV-USG:terminated_at"=>nil,
    # "OS-EXT-AZ:availability_zone"=>"nova", "user_id"=>"f101ca72d329404c83ed253d60829f29", "name"=>"wn-golden-image-backup", "created"=>"2015-01-19T14:49:21Z",
    # "tenant_id"=>"969af8e3338c4f0a9f434d5a8941bcc2", "OS-DCF:diskConfig"=>"AUTO", "os-extended-volumes:volumes_attached"=>[],
    # "accessIPv4"=>"", "accessIPv6"=>"", "progress"=>0, "OS-EXT-STS:power_state"=>1, "config_drive"=>"", "metadata"=>{}}}

    servers = []
    all_servers = []
    Retryable.retryable(:tries => 5, :sleep => 2, :on => Fog::Errors::NotFound) do
      all_servers = @compute.list_servers.data[:body]["servers"]
    end

    all_servers.each do |server|
      if server["name"] =~ /^*wn*/
        servers << server
      end
    end

    if @debug
      counter=0
      servers.each do |server|
        p "#{counter+=1} #{server["name"]} - #{server["id"]}"
      end
    end

    servers_detailed = {} # you must not have servers with the same name
    #get detailed view of servers and return it
    servers.each do |server|
      Retryable.retryable(:tries => 5, :sleep => 2, :on => Fog::Errors::NotFound) do
        servers_detailed[server["name"]] = @compute.get_server_details(server["id"]).data[:body]["server"]
      end
    end

    servers_detailed
  end


  def get_current_images
    images = nil
    Retryable.retryable(:tries => 5, :sleep => 2, :on => Fog::Errors::NotFound) do
      images = @compute.list_images.data[:body]["images"]
    end

    counter=0
    image_dict = {} # you must not have images with the same name
    if @debug
      images.each do |image|
        counter += 1
        p "#{counter}. #{image["id"]} #{image["name"]}"
        image_dict[image["name"]] = image
      end
    end
    image_dict
  end


  def create_server(name, image, flavor, nic, float_pool) # set name from outside
    # {"nics" => [:net_id => '9456d7b8-1aa7-40e2-a2ff-8970c1e2b1e0']}
    response = nil
    Retryable.retryable(:tries => 5, :sleep => 2, :on => Fog::Errors::NotFound) do
      begin
        response = @compute.create_server(name, image, flavor, {"nics" => [:net_id => nic]})
      rescue Excon::Errors::RequestEntityTooLarge => ex
        p ex.response.data[:body]
        return response
      end
    end

    if @debug
      pp response["server"]
    end

    @openstack_vm_counter += 1
    id = response.data[:body]['server']['id']

    # allocate floating ip
    float_ip = @compute.allocate_address float_pool unless float_pool.nil?
    @compute.associate_address id, float_ip

    {name => {'id'=>id, 'float_ip'=>float_ip}}
  end

  def terminate_server(name)
    id = search_server_by_name name
    associated_ips = get_associated_floating_ips name
    associated_ips.each do |float_ip|
      @compute.disassociate_address id, float_ip
      p "deleting "+float_ip+" with "+search_floating_ip_by_ip(float_ip)
      @compute.release_address search_floating_ip_by_ip(float_ip)
    end
    @compute.delete_server search_server_by_name name
    @openstack_vm_counter -= 1
  end

  def start_server(name)
    begin
      @compute.start_server search_server_by_name name
    rescue Excon::Errors::Conflict => ex
      p "Already running"
    end
  end

  def shutdown_server(name)
    begin
      @compute.stop_server search_server_by_name name
    rescue Excon::Errors::Conflict => ex
      p "Already shutoff"
    end
  end

  # private

  def search_server_by_name(name)
    vms = get_current_vms
    vms[name]["id"]
  end

  def get_floating_ips
    # ip, fixed_ip, id, pool
    @compute.list_all_addresses.data[:body]['floating_ips']
  end

  def search_floating_ip_by_ip(ip)
    get_floating_ips.each do |ip_entry|
      if ip_entry["ip"] = ip
        return ip_entry["id"]
      end
    end
  end

  def get_associated_floating_ips name
    vms = get_current_vms
    addresses = vms[name]["addresses"]

    associated_floating_addresses = []
    addresses.each_pair do |key, address|
      address.each do |addr|
        if addr["OS-EXT-IPS:type"] == "floating"
          associated_floating_addresses << addr['addr']
        end
      end
    end
    associated_floating_addresses
  end
end

#   def self.create_vms(n)
#     # Create n new servers.
#     newservers = []
#
#     begin
#       n.times do |counter|
#         retryable(:tries => 3, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
#           newservers << @@os.create_server(:name => "vm-wn-#{@@counter}", :imageRef => ScalerConfig.image_id, :flavorRef => ScalerConfig.flavor_id, :security_groups => ['default', 'Torque-WN'], :key_name=>"test_key_set")
#         end
#
#         p "Counter = " + @@counter.to_s if ScalerConfig.debug
#
#         @@counter+=1
#         sleep(1)
#       end
#     rescue OpenStack::Exception::OverLimit
#       p "InstanceLimitExceeded: Instance quota exceeded. You cannot run any more instances of this type."
#     end
#
#     if ScalerConfig.debug
#       p "Printing new servers:"
#       p newservers
#       p newservers.collect {|n_s| n_s.name}
#     end
#
#     # Check if all servers are online and get IP addresses + fqdn + name in an array.
#     # e.g. [[10.0.0.1, vm-00.grid.auth.gr, vm-00], [10.0.0.2, vm-01.grid.auth.gr, vm-01] ...]
#     ip_name_fqdn_array = vms_ips(newservers)
#
#     if ScalerConfig.debug
#       p "ip_name_fqdn_array is :"
#       p ip_name_fqdn_array
#     end
#     # ip_addresses << [vm.addresses.first.address, vm.name + ".grid.auth.gr", vm.name]
#     ip_list, fqdn_list = [], []
#     ip_name_fqdn_array.each {|ip_name_fqdn| ip_list << ip_name_fqdn[0]; fqdn_list << ip_name_fqdn[1]}
#     # Give some time to VMs to get up.
#     p "Give some time to VMs to get up." if ScalerConfig.debug
#     sleep(10)
#
#     # Check if yaim is finished to all vms.
#     VMHandler.yaim_terminated_in_each_host?(ip_list)
#
#     # Add new vms to cream files.
#     CreamHandler.write_to_hosts(ip_name_fqdn_array)
#     CreamHandler.add_wns_to_wn_list(fqdn_list)
#
#     # Restart cream services.
#     CreamHandler.restart_yaim!
#
#     if ScalerConfig.debug
#       p "Current servers:"
#       p @@allservers
#     end
#   end
#
#   def self.delete_vms(n)
#     return if n > @@allservers.count
#
#     p "We need to decrease our infrastructure!"
#
#     # Delete n servers.
#     deleted_servers = []
#
#     n.times do |counter|
#       retryable(:tries => 3, :sleep => 2, :on => OpenStack::Exception::Other) do
#         @@allservers.first[:vm_ref].refresh
#
#         # We do the shift after delete!, just in case delete! method fails due to network.
#         if @@allservers.first[:vm_ref].status == "ACTIVE"
#           @@allservers.first[:vm_ref].delete!
#           deleted_servers << @@allservers.shift
#         end
#       end
#     end
#
#     # Delete vms from cream files.
#     ip_list, fqdn_list = [], []
#     deleted_servers.each {|d_s| ip_list << d_s[:address]; fqdn_list << d_s[:fqdn] }
#     CreamHandler.delete_from_hosts(ip_list)
#     CreamHandler.delete_wns_from_wn_list(fqdn_list)
#
#     # Restart cream services.
#     CreamHandler.restart_yaim!
#   end
#
#   ################## Private members ##################
#   private
#
#   def self.vms_ips(vms)
#     flag = true
#     ip_addresses = []
#
#     while flag
#       # Server refreshing
#       p "Server refreshing" if ScalerConfig.debug
#       vms.each do |server|
#         retryable(:tries => 3, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
#           server.refresh
#         end
#       end
#
#       # Check if all servers are active.
#       i = 0
#       vms.each do |vm|
#         if vm.status == "ACTIVE"
#           i+=1
#         end
#       end
#
#       if ScalerConfig.debug
#         p "Number of active vms:"
#         p i
#         p "Number of vms:"
#         p vms.count
#       end
#
#       if i == vms.count
#         flag = false
#       end
#
#       sleep(10)
#     end
#
#     # Get all ip addresses.
#     vms.each do |vm|
#       ip_addresses << [vm.addresses.first.address, vm.name + ".grid.auth.gr", vm.name]
#       # Save new servers.
#       @@allservers << {:vm_ref => vm, :address => vm.addresses.first.address, :fqdn => vm.name + ".grid.auth.gr", :name => vm.name}
#     end
#
#     return ip_addresses
#   end
# end