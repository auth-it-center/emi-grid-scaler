require 'net/ssh'

class VMHandler
  
  def self.yaim_terminated_in_each_host?(ip_addresses)
    
    if ScalerConfig.debug
      p "Checking if YAIM is terminated in:"
      p ip_addresses
    end

    host_finished = 0
    
    while host_finished < ip_addresses.count
      host_finished = 0
      
      ip_addresses.each do |ip_address|
        retryable(:tries => 5, :sleep => 5, :on => [Errno::ECONNREFUSED, Errno::EHOSTUNREACH]) do
          host_finished += yaim_terminated?(ip_address)
        end
      end
      
      if ScalerConfig.debug
        p "Number of finished hosts is:"
        p host_finished
      end
      
      sleep(5)
    end
  end
  
  def self.yaim_terminated?(ip_address)
    last_line = ""
    
    Net::SSH.start( ip_address, 'root', :paranoid => false ) do |session|
      last_line = session.exec!('tail -n1 /opt/glite/yaim/log/yaimlog')
    end
    
    if ScalerConfig.debug
      p "Last line in #{ip_address} is:"
      p last_line
    end
    
    # last_line = %x[ssh ansible@#{ip_address} tail -n1 /opt/glite/yaim/log/yaimlog]
    
    last_line.strip.include?("terminated succesfully") ? 1 : 0
  end
end