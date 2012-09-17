require 'rubygems'
require 'openstack'
require 'retryable'

class OpenstackHandler
  @@debug = false
  @@debug_openstack = false
  
  @@counter = 0
  
  @@flavor_id = 2
  @@image_id = 50

  @@allservers = []
  
  def self.debug=(debug)
    @@debug = debug
  end
  
  def self.debug_openstack=(debug)
    @@debug_openstack = debug
  end
  
  def self.init_client
    retryable(:tries => 3, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
      os = OpenStack::Connection.create({:username => "cream", 
                                        :api_key=>"cream", 
                                        :auth_url => "http://192.168.124.81:5000/v1.1/", 
                                        :authtenant_name =>"scc-61",
                                        :is_debug => @@debug_openstack}) 
    end
    
    inspect os if @@debug
  end
  
  def self.create_vms(n)
    # Create n new servers.
    newservers = []
    
    n.times do |counter|
      retryable(:tries => 3, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
        newservers << os.create_server(:name => "vm-wn-#{@@counter}", :imageRef => @@image_id, :flavorRef => @@flavor_id)
      end
      
      p "Counter = " + @@counter if @@debug
      
      @@counter+=1
      sleep(1)
    end
    
    p newservers.collect {|n_s| n_s.name} if @@debug
    
    # Check if all servers are online and get IP addresses + name + fqdn in an array.
    # e.g. [[10.0.0.1, vm-00, vm-00.grid.auth.gr], [10.0.0.2, vm-01, vm-01.grid.auth.gr], ...]
    p "ip_name_fqdn_array is :" if @@debug
    p ip_name_fqdn_array if @@debug
    ip_name_fqdn_array = vms_ips(newservers)
    
    # Check if yaim is finished to all vms.
    ip_addresses = ip_name_fqdn_array.collect {|ip_name_fqdn| ip_name_fqdn.first}
    VMHandler.yaim_terminated_in_each_host?(ip_addresses)
    
    # Add new vms to cream files.
    CreamHandler.write_to_hosts(ip_name_fqdn_array)
    fqdns = ip_name_fqdn_array.collect {|ip_name_fqdn| ip_name_fqdn.last}
    CreamHandler.add_wns_to_wn_list(fqdns)
    
    # Restart cream services.
    CreamHandler.restart_yaim!
  end
  
  def self.delete_vms(n)
    # Delete n servers.
    
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
            
      if i == vms.count
        flag = false
      end

      sleep(10)
    end
    
    # Get all ip addresses.
    vms.each do |vm|
      ip_addresses << [vm.addresses.first.address, vm.name, vm.name + ".grid.auth.gr"]
    end
    
    return ip_addresses
  end
end