#!/usr/bin/env ruby
require 'rubygems'
require 'cream_handler'
require 'openstack_handler'

INCREASE_VM_CONSTANT = 3

p "Welcome to Openstack Scaler."

# Debug options
OpenstackHandler.debug = true
OpenstackHandler.debug_openstack = false
CreamHandler.debug = true
VMHandler.debug = true

p "Initialazing openstack client."

OpenstackHandler.init_client

while true
  
  p "Lets get the stats!"
  stats = CreamHandler.queue_stats
  p stats
  p "===================================="

  if stats[:idle_jobs] > stats[:total_processors]
    # Increase VMs.
    p "We need to scale!"
    OpenstackHandler.create_vms(INCREASE_VM_CONSTANT)
  else
    # Decrease VMs.
  end
  
  p "Lets wait for 1 min."
  sleep(60) # 10 min
end