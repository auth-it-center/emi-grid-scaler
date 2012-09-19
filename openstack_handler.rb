require 'rubygems'
require 'openstack'
require 'retryable'

class OpenstackHandler  
  @@counter = 0
  
  @@os = nil
  @@allservers = []
  
  def self.counter
    return @@counter
  end
    
  def self.init_client
    retryable(:tries => 5, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
      @@os = OpenStack::Connection.create({:username => "cream", 
                                        :api_key=>"cream", 
                                        :auth_url => "http://192.168.124.81:5000/v1.1/", 
                                        :authtenant_name =>"scc-61",
                                        :is_debug => ScalerConfig.debug_openstack}) 
    end
    
    if @@allservers == []
      retryable(:tries => 5, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
        servers = @@os.servers
      end
      
      ids = []
      
      servers.each do |server|
        if server[:name] =~ /^vm-wn-.*/
          ids << server[:id]
        end
      end

      ids.each do |id|
        retryable(:tries => 5, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
          vm = @@os.get_server(id)
          @@allservers << {:vm_ref => vm, :address => vm.addresses.first.address, :fqdn => vm.name + ".grid.auth.gr", :name => vm.name}
        end
      end
    end
    
    if ScalerConfig.debug
      p "Current servers from init:"
      p @@allservers
    end
  end
  
  def self.create_vms(n)
    # Create n new servers.
    newservers = []
    
    begin
      n.times do |counter|
        retryable(:tries => 3, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
          newservers << @@os.create_server(:name => "vm-wn-#{@@counter}", :imageRef => ScalerConfig.image_id, :flavorRef => ScalerConfig.flavor_id, :security_groups => ['default', 'Torque-WN'], :key_name=>"test_key_set")
        end

        p "Counter = " + @@counter.to_s if ScalerConfig.debug

        @@counter+=1
        sleep(1)
      end
    rescue OpenStack::Exception::OverLimit
      p "InstanceLimitExceeded: Instance quota exceeded. You cannot run any more instances of this type."
    end
    
    if ScalerConfig.debug
      p "Printing new servers:"
      p newservers
      p newservers.collect {|n_s| n_s.name}
    end
        
    # Check if all servers are online and get IP addresses + name + fqdn in an array.
    # e.g. [[10.0.0.1, vm-00.grid.auth.gr, vm-00], [10.0.0.2, vm-01.grid.auth.gr, vm-01] ...]
    ip_name_fqdn_array = vms_ips(newservers)

    if ScalerConfig.debug
      p "ip_name_fqdn_array is :"
      p ip_name_fqdn_array
    end
    
    ip_list, fqdn_list = [], []
    ip_name_fqdn_array.each {|ip_name_fqdn| ip_list << ip_name_fqdn.first; fqdn_list << ip_name_fqdn[1]}
    # Give some time to VMs to get up.
    p "Give some time to VMs to get up." if ScalerConfig.debug
    sleep(10)
    
    # Check if yaim is finished to all vms.
    VMHandler.yaim_terminated_in_each_host?(ip_list)
    
    # Add new vms to cream files.
    CreamHandler.write_to_hosts(ip_name_fqdn_array)
    CreamHandler.add_wns_to_wn_list(fqdn_list)
    
    # Restart cream services.
    CreamHandler.restart_yaim!
    
    if ScalerConfig.debug
      p "Current servers:"
      p @@allservers
    end
  end
  
  def self.delete_vms(n)
    # Delete n servers.
    deleted_servers = []
    
    n.times do |counter|
      retryable(:tries => 3, :sleep => 2, :on => OpenStack::Exception::Other) do
        @@allservers.first[:vm].refresh
        
        # We do the shift after delete!, just in case delete! method fails due to network.
        if @@allservers.first[:vm].status == "ACTIVE"
          @@allservers.first[:vm].delete!
          deleted_servers << @@allservers.shift
        end
      end
    end
        
    # Delete vms from cream files.
    ip_list, fqdn_list = [], []
    deleted_servers.each {|d_s| ip_list << d_s[:address]; fqdn_list << d_s[:fqdn] }
    CreamHandler.delete_from_hosts(ip_list)
    CreamHandler.delete_wns_from_wn_list(fqdn_list)
    
    # Restart cream services.
    CreamHandler.restart_yaim!
  end
  
  ################## Private members ################## 
  private
  
  def self.vms_ips(vms)
    flag = true
    ip_addresses = []
    
    while flag
      # Server refreshing
      p "Server refreshing" if ScalerConfig.debug
      vms.each do |server| 
        retryable(:tries => 3, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
          server.refresh
        end
      end

      # Check if all servers are active.
      i = 0
      vms.each do |vm| 
        if vm.status == "ACTIVE"
          i+=1
        end
      end
      
      if ScalerConfig.debug
        p "Number of active vms:"
        p i
        p "Number of vms:"
        p vms.count
      end
      
      if i == vms.count
        flag = false
      end

      sleep(10)
    end
    
    # Get all ip addresses.
    vms.each do |vm|
      ip_addresses << [vm.addresses.first.address, vm.name + ".grid.auth.gr", vm.name]
      # Save new servers.
      @@allservers << {:vm_ref => vm, :address => vm.addresses.first.address, :fqdn => vm.name + ".grid.auth.gr", :name => vm.name}
    end
    
    return ip_addresses
  end
end