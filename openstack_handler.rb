require 'rubygems'
require 'openstack'
require 'retryable'

class OpenstackHandler  
  @@counter = 0
  
  @@os = nil
  @@allservers = []
    
  def self.init_client
    retryable(:tries => 3, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
      @@os = OpenStack::Connection.create({:username => "cream", 
                                        :api_key=>"cream", 
                                        :auth_url => "http://192.168.124.81:5000/v1.1/", 
                                        :authtenant_name =>"scc-61",
                                        :is_debug => Config.debug_openstack}) 
    end
  end
  
  def self.create_vms(n)
    # Create n new servers.
    newservers = []
    
    begin
      n.times do |counter|
        retryable(:tries => 3, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
          newservers << @@os.create_server(:name => "vm-wn-#{@@counter}", :imageRef => Config.image_id, :flavorRef => Config.flavor_id, :security_groups => ['default', 'Torque-WN'], :key_name=>"test_key_set")
        end

        p "Counter = " + @@counter.to_s if Config.debug

        @@counter+=1
        sleep(1)
      end
    rescue OpenStack::Exception::OverLimit
      p "InstanceLimitExceeded: Instance quota exceeded. You cannot run any more instances of this type."
    end
    
    
    p "Printing new servers:" if Config.debug
    p newservers if Config.debug
    p newservers.collect {|n_s| n_s.name} if Config.debug
    
    # Check if all servers are online and get IP addresses + name + fqdn in an array.
    # e.g. [[10.0.0.1, vm-00, vm-00.grid.auth.gr], [10.0.0.2, vm-01, vm-01.grid.auth.gr], ...]
    ip_name_fqdn_array = vms_ips(newservers)

    p "ip_name_fqdn_array is :" if Config.debug
    p ip_name_fqdn_array if Config.debug
    
    # Check if yaim is finished to all vms.
    ip_addresses = ip_name_fqdn_array.collect {|ip_name_fqdn| ip_name_fqdn.first}
    VMHandler.yaim_terminated_in_each_host?(ip_addresses)
    
    # Add new vms to cream files.
    CreamHandler.write_to_hosts(ip_name_fqdn_array)
    fqdns = ip_name_fqdn_array.collect {|ip_name_fqdn| ip_name_fqdn[1]}
    CreamHandler.add_wns_to_wn_list(fqdns)
    
    # Restart cream services.
    CreamHandler.restart_yaim!
    
    # Save new servers.
    @@allservers += newservers
  end
  
  def self.delete_vms(n)
    # Delete n servers.
    n.times do |counter|
      
    end
    
    @@allservers.each do |server|
    end
    
    # Delete vms from cream files.
    
    # Restart cream services.
  end
  
  def self.counter
    return @@counter
  end
  
  ################## Private members ################## 
  private
  
  def self.vms_ips(vms)
    flag = true
    ip_addresses = []
    
    while flag
      # Server refreshing
      p "Server refreshing" if Config.debug
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
      
      if Config.debug
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
    end
    
    return ip_addresses
  end
end