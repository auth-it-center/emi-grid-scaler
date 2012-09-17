#!/usr/bin/env ruby
require 'cream_handler'
require 'openstack_handler'

standard_inscrease_VM_constant = 10

while true
  
  stats = CreamHandler.get_queue_stats

  if stats[:idle_jobs] > stats[:total_processors]
    # Increase VMs.

  else
    # Decrease VMs.
  end
  
  sleep(600) # 10 min
end