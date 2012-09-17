require 'net/ssh'

class VMHandler

  @@debug = false
  
  def self.debug=(debug)
    @@debug = debug
  end
  
  def self.yaim_terminated_in_each_host?(ip_addresses)
    
    p "Checking if YAIM is terminated in:" if @@debug
    p ip_addresses if @@debug

    host_finished = 0
    
    while host_finished < ip_addresses.count
      host_finished = 0
      
      ip_addresses.each do |ip_address|
        retryable(:tries => 3, :sleep => 5, :on => Errno::ECONNREFUSED) do
          host_finished += yaim_terminated?(ip_address)
        end
      end
      
      p "Number of finished hosts is:" if @@debug
      p host_finished if @@debug
      
      sleep(5)
    end
  end
  
  def self.yaim_terminated?(ip_address)
    last_line = ""
    
    Net::SSH.start( ip_address, 'root', :paranoid => false ) do |session|
      last_line = session.exec!('tail -n1 /opt/glite/yaim/log/yaimlog')
    end
    
    p "Last line in #{ip_address} is:" if @@debug
    p last_line if @@debug
    
    # last_line = %x[ssh ansible@#{ip_address} tail -n1 /opt/glite/yaim/log/yaimlog]
    
    last_line.strip.include?("terminated succesfully") ? 1 : 0
  end
end