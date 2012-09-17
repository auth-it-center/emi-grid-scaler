require 'net/ssh'

class CreamHandler
  @@local = true
  @@debug = false
  
  @@etc_hosts_file_path = '/etc/hosts'
  
  @@wn_list_conf = '/opt/glite/yaim/etc/siteinfo/wn-list.conf'
  
  def self.debug=(debug)
    @@debug = debug
  end
  
  def self.local=(local)
    @@local = local
  end
  
  def self.local
    @@local
  end
  
  def self.queue_stats
    stats = {}
    showq_cmd = ""
    
    if @@local
      showq_cmd = %x[showq]
    else
      # Net::SSH.start( 'cream.afroditi.hellasgrid.gr', 'ansible' ) do |session|
      #   showq_cmd = session.exec!('showq')
      # end
    end

    stats[:total_jobs], stats[:active_jobs], stats[:idle_jobs], stats[:blocked_jobs] = showq_cmd.match(/^Total Jobs: (\d+)   Active Jobs: (\d+)   Idle Jobs: (\d+)   Blocked Jobs: (\d+)$/).captures

    stats[:working_processors], stats[:total_processors] = showq_cmd.match(/(\d+) of   (\d+) Processors Active/).captures

    stats[:working_nodes], stats[:total_nodes] = showq_cmd.match(/(\d+) of   (\d+) Nodes Active/).captures
    
    if @@debug
      p "======================================================"
      p "======================================================"
      p "               Information from cream.                "
      p "======================================================"
      p "working_nodes, total_nodes"
      print "#{stats[:working_nodes]}, \t #{stats[:total_nodes]}"
      p "==="
      p "working_processors, total_processors"
      print "#{stats[:working_processors]}, \t #{stats[:total_processors]}"
      p "==="
      p "total_jobs, active_jobs, idle_jobs, blocked_jobs"
      print "#{stats[:total_jobs]}, \t #{stats[:active_jobs]}, \t #{stats[:idle_jobs]}, \t #{stats[:blocked_jobs]}"
      p "======================================================"
      p "======================================================"
      p "======================================================"
    end
    
    stats
  end
  
  def self.write_to_hosts(list)

    etc_hosts_file = File.open(@etc_hosts_file_path, 'a')

    list.each do |ip_name_fqdn|
      etc_hosts_file.write ip_name_fqdn.join(' ') + '\n'
    end
    
    etc_hosts_file.close
  end
  
  def self.delete_from_hosts(list)
        
    etc_hosts_lines = File.readlines(@etc_hosts_file_path)
    
    etc_hosts_lines.reject! {|line| list.include?(line.split.first) }
    
     File.open(@etc_hosts_file_path, 'w') {|f| f.write etc_hosts_lines.join('\n') }
  end
  
  def self.add_wns_to_wn_list(list)
    
    wn_list_conf_file = File.open(@wn_list_conf, 'a')

    list.each do |fqdn|
      wn_list_conf_file.write fqdn + '\n'
    end
    
    wn_list_conf_file.close
  end
  
  def self.delete_wns_from_wn_list(list)
    wn_list_conf_lines = File.readlines(@wn_list_conf)
    
    wn_list_conf_lines.reject! {|line| list.include? line.strip! }
    
     File.open(@etc_hosts_file_path, 'w') {|f| f.write wn_list_conf_lines.join('\n') }
  end
  
  def self.restart_yaim!
    p "Restarting YAIM!" if @@debug
    %x[/opt/glite/yaim/bin/yaim -c -s /opt/glite/yaim/etc/siteinfo/site-info.def -n creamCE -n TORQUE_server -n TORQUE_utils -n BDII_site]
    
    $?.exitstatus
  end  
end