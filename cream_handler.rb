#!/usr/bin/env ruby
require 'rubygems'
require 'net/ssh'
require_relative 'scaler_config'

class CreamHandler

  attr_reader :ip
  # Configuration class variables and accessors
  @@debug = true

  def self.debug=(debug)
    @@debug = debug
  end

  def self.debug
    @@debug
  end

  def self.cream_local?(ip)
    if ip == 'localhost'
      return true
    else
      return false
    end
  end
  ###################################

  @@etc_hosts_file_path = '/etc/hosts'
  @@wn_list_conf_path = '/opt/glite/yaim/etc/siteinfo/wn-list.conf'

  def initialize(ip='localhost', user=nil)
    @ip = ip
    @user = user
    if !CreamHandler.cream_local?(@ip) && @user.nil?
      raise(ArgumentError, 'must specify user when cream is not local')
    end
  end


  def queue_stats
    stats = {}
    showq_cmd = ""

    begin
      if CreamHandler.cream_local?(@ip)
        showq_cmd = %x[showq]
      else
        Net::SSH.start( @ip, @user ) do |session|
          showq_cmd = session.exec!('showq')
        end
      end

    rescue Exception
      raise
    end

    stats[:total_jobs], stats[:active_jobs], stats[:idle_jobs], stats[:blocked_jobs] = showq_cmd.match(/Total Jobs: (\d+)\s+Active Jobs: (\d+)\s+Idle Jobs: (\d+)\s+Blocked Jobs: (\d+)/).captures.collect {|d| d.to_i}

    stats[:working_processors], stats[:total_processors] = showq_cmd.match(/(\d+) of\s+(\d+) Processors Active/).captures.collect {|d| d.to_i}

    # this is not present always
    stats[:working_nodes], stats[:total_nodes] = showq_cmd.match(/(\d+) of\s+(\d+) Nodes Active/).captures.collect {|d| d.to_i}
    
    if CreamHandler.debug
      p "======================================================"
      p "======================================================"
      p "               Information from cream.                "
      p "======================================================"
      p "working_nodes, total_nodes"
      print "#{stats[:working_nodes]}, \t #{stats[:total_nodes]}\n"
      p "==="
      p "working_processors, total_processors"
      print "#{stats[:working_processors]}, \t #{stats[:total_processors]}\n"
      p "==="
      p "total_jobs, active_jobs, idle_jobs, blocked_jobs"
      print "#{stats[:total_jobs]}, \t #{stats[:active_jobs]}, \t #{stats[:idle_jobs]}, \t #{stats[:blocked_jobs]}\n"
      p "======================================================"
      p "======================================================"
      p "======================================================"
    end
    
    stats
  end
  
  def write_to_hosts(list, hosts_file_path=@@etc_hosts_file_path, sudo_to_write=false)

    # TODO: Read the whole host file and delete duplicates before committing
    # prepare string to append
    string_to_append = ""
    list.each do |ip_name_fqdn|
      string_to_append << "#{ip_name_fqdn.join(' ')}\n"
    end

    remote_etc_hosts_file = ''

    if CreamHandler.cream_local? @ip
      if sudo_to_write
        %x[sudo echo -e #{string_to_append} >> #{hosts_file_path}]
      else
        etc_hosts_file = File.open(hosts_file_path, 'a')
        etc_hosts_file.write(string_to_append)
        etc_hosts_file.close
      end
    else
      Net::SSH::start(@ip, @user) do |session|
        if sudo_to_write
          remote_etc_hosts_file = session.exec!("sudo echo -e #{string_to_append} >> #{hosts_file_path};sudo cat -e #{hosts_file_path}")
        else
          remote_etc_hosts_file = session.exec!("echo -e #{string_to_append} >> #{hosts_file_path};cat #{hosts_file_path}")
        end
      end
    end

    if CreamHandler.debug
      if CreamHandler.cream_local? @ip
        p "Printing /etc/hosts new file"
        p File.readlines(hosts_file_path)
      else
        p remote_etc_hosts_file
      end
    end
  end

  def delete_from_hosts(ip_list, hosts_file_path=@@etc_hosts_file_path, sudo_to_delete=false)

    etc_hosts_lines = []
    # return false unless File.exist?(hosts_file_path)
    if CreamHandler.cream_local? @ip
      etc_hosts_lines = File.readlines(hosts_file_path)
    else
      Net::SSH.start(@ip, @user) do |session|
        etc_hosts_lines = session.exec!("cat #{hosts_file_path}").split("\n")
      end
    end

    etc_hosts_lines.reject! {|line| ip_list.include? line.split.first }
    string_to_be_written = etc_hosts_lines.join("\n")

    CreamHandler.fix_file_lines(etc_hosts_lines)

    remote_hosts_lines = ''
    if CreamHandler.cream_local? @ip
      File.open(hosts_file_path, 'w') {|f| f.write string_to_be_written}
    else
      Net::SSH.start(@ip, @user) do |session|
        if sudo_to_delete
          remote_hosts_lines = session.exec!("sudo -i; echo #{string_to_be_written} > #{hosts_file_path};cat #{hosts_file_path}")
        else
          remote_hosts_lines = session.exec!("echo #{string_to_be_written} > #{hosts_file_path};cat #{hosts_file_path}")
        end
      end
    end

    if CreamHandler.debug
      p "Printing #{hosts_file_path} new file"
      if CreamHandler.cream_local? @ip
        p File.readlines(hosts_file_path)
      else
        p remote_hosts_lines
      end
    end

    etc_hosts_lines
  end

  def add_wns_to_wn_list(fqdn_list, wns_file_path=@@wn_list_conf_path, sudo_to_write=false)

    # wn_list_conf_file = File.open(@@wn_list_conf_path, 'a')
    if CreamHandler.cream_local? @ip
      wn_list_conf_lines = File.readlines(wns_file_path)
    else
      Net::SSH.start(@ip, @user) do |session|
        if sudo_to_write
          wn_list_conf_lines = session.exec!("sudo -i; cat #{wns_file_path}")
        else
          wn_list_conf_lines = session.exec!("cat #{wns_file_path}")
        end
      end
      wn_list_conf_lines = wn_list_conf_lines.split("\n")
      CreamHandler.fix_file_lines wn_list_conf_lines
    end


    # # Check if all lines have a \n at the end.
    # CreamHandler.fix_file_lines(wn_list_conf_lines)

    fqdn_list.each do |fqdn|
      wn_list_conf_lines << "#{fqdn}\n"
    end

    # Remove duplicates, if any
    wn_list_conf_lines.uniq!
    # Sort lines
    wn_list_conf_lines.sort!

    string_to_be_written = ''
    wn_list_conf_lines.each do |line|
      string_to_be_written << "#{line}"
    end

    # Add one empty line at the end.
    # wn_list_conf_file.write "\n"

    remote_wns_file = ''

    if CreamHandler.cream_local? @ip
      # Write file.
      if sudo_to_write
        %x[sudo echo -e #{string_to_be_written} > #{wns_file_path}]
      else
        File.open(wns_file_path, 'w') {|f| f.write string_to_be_written }
      end
    else
      Net::SSH.start(@ip, @user) do |session|
        if sudo_to_write
          remote_wns_file = session.exec!("sudo -i; echo -e #{string_to_be_written} > #{wns_file_path};cat -e #{wns_file_path}")
        else
          remote_wns_file = session.exec!("echo -e #{string_to_be_written} > #{wns_file_path};cat #{wns_file_path}")
        end
      end
    end



    if CreamHandler.debug
      p "Printing wn-list.conf new file"
      if CreamHandler.cream_local? @ip
        p File.readlines(wns_file_path)
      else
        p remote_wns_file
      end
    end

  end

  def delete_wns_from_wn_list(fqdn_list, wns_file_path=@@wn_list_conf_path, sudo_to_write=false)

    if CreamHandler.cream_local? @ip
      wn_list_conf_lines = File.readlines(wns_file_path)
    else
      Net::SSH.start(@ip, @user) do |session|
        if sudo_to_write
          wn_list_conf_lines = session.exec!("sudo cat #{wns_file_path}")
        else
          wn_list_conf_lines = session.exec!("cat #{wns_file_path}")
        end
        wn_list_conf_lines = wn_list_conf_lines.split("\n")
        CreamHandler.fix_file_lines wn_list_conf_lines
      end
    end


    wn_list_conf_lines.reject! {|line| fqdn_list.include? line.strip! }

    string_to_be_written = ''
    wn_list_conf_lines.each do |line|
      string_to_be_written << "#{line}\n"
    end

    remote_wns_file = ''
    if CreamHandler.cream_local? @ip
      # Write file.
      if sudo_to_write
        %x[sudo echo -e #{string_to_be_written} > #{wns_file_path}]
      else
        File.open(wns_file_path, 'w') {|f| f.write string_to_be_written }
      end
    else
      Net::SSH.start(@ip, @user) do |session|
        if sudo_to_write
          remote_wns_file = session.exec!("sudo -i; echo -e #{string_to_be_written} > #{wns_file_path};cat -e #{wns_file_path}")
        else
          remote_wns_file = session.exec!("echo -e #{string_to_be_written} > #{wns_file_path};cat #{wns_file_path}")
        end
      end
    end

    if CreamHandler.debug
      p "Printing wn-list.conf new file"
      if CreamHandler.cream_local? @ip
        p File.readlines(wns_file_path)
      else
        p remote_wns_file
      end
    end
  end
#
  def restart_yaim!(need_for_sudo=false)
    p "Restarting YAIM!" if ScalerConfig.debug

    if ScalerConfig.cream_local? @ip
      #yaim_cmd = '/opt/glite/yaim/bin/yaim -c -s /opt/glite/yaim/etc/siteinfo/site-info.def -n creamCE -n TORQUE_server -n TORQUE_utils -n BDII_site'
      if need_for_sudo
        yaim_cmd = 'sudo -i; /opt/glite/yaim/bin/yaim -r -s /opt/glite/yaim/etc/siteinfo/site-info.def'\
                 '-n creamCE -n TORQUE_server -n TORQUE_utils -n BDII_site -f config_torque_server -f config_maui_cfg -f config_torque_submitter_ssh'
      else
        yaim_cmd = '/opt/glite/yaim/bin/yaim -r -s /opt/glite/yaim/etc/siteinfo/site-info.def'\
                 '-n creamCE -n TORQUE_server -n TORQUE_utils -n BDII_site -f config_torque_server -f config_maui_cfg -f config_torque_submitter_ssh'
      end
      IO.popen(yaim_cmd, mode='r') do |cmd_stream|
        until cmd_stream.eof?
          puts cmd_stream.gets
        end
      end
    else
      Net::SSH.start( @ip, @user ) do |session|
        #session.exec!('sudo -i /opt/glite/yaim/bin/yaim -c -s /opt/glite/yaim/etc/siteinfo/site-info.def -n creamCE -n TORQUE_server -n TORQUE_utils -n BDII_site') do |ch, stream, line|
        if need_for_sudo
          session.exec!('/opt/glite/yaim/bin/yaim -r -s /opt/glite/yaim/etc/siteinfo/site-info.def'\
           '-n creamCE -n TORQUE_server -n TORQUE_utils -n BDII_site -f config_torque_server -f config_maui_cfg -f config_torque_submitter_ssh') do |ch, stream, line|
          puts line if ScalerConfig.debug
          end

        else
          session.exec!('sudo -i; /opt/glite/yaim/bin/yaim -r -s /opt/glite/yaim/etc/siteinfo/site-info.def'\
           '-n creamCE -n TORQUE_server -n TORQUE_utils -n BDII_site -f config_torque_server -f config_maui_cfg -f config_torque_submitter_ssh') do |ch, stream, line|
            puts line if ScalerConfig.debug
          end
        end
      end
    end

    $?.exitstatus
  end
#
  ################## Private members ##################
  private

  def self.fix_file_lines(file_lines)
    file_lines.map! {|l| unless l =~ /.*\n$/ then l += "\n" else l end }
  end
end