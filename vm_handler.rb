require 'net/ssh'

class VMHandler
  
  def self.yaim_terminated_in_each_host?(ip_addresses)
    host_finished = 0
    
    while host_finished < ip_addresses.count
      host_finished = 0
      
      ip_addresses.each do |ip_address|
        host_finished += yaim_terminated?(ip_address)
      end
      
      sleep(5)
    end
  end
  
  def self.yaim_terminated?(ip_address)
    last_line = ""
    
    Net::SSH.start( ip_address, 'ansible' ) do |session|
      last_line = session.exec!('tail -n1 /opt/glite/yaim/log/yaimlog')
    end
    
    # last_line = %x[ssh ansible@#{ip_address} tail -n1 /opt/glite/yaim/log/yaimlog]
    
    last_line.strip.include?("terminated succesfully") ? 1 : 0
  end
end