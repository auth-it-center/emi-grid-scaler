#!/usr/bin/env ruby
require 'rubygems'
require 'scaler_config'
require 'cream_handler'
require 'openstack_handler'
require 'vm_handler'

VM_CONSTANT = 3

p "Welcome to Openstack Scaler."

# Config options
ScalerConfig.debug = true
ScalerConfig.debug_openstack = false
ScalerConfig.cream_local = true

p "Initialazing openstack client."

OpenstackHandler.init_client

state = 1

while true
  p "state:"
  p state
  p "Lets get the stats!"
  stats = CreamHandler.queue_stats
  p stats
  p "===================================="

  if state == 0 #stats[:idle_jobs] > stats[:total_processors]
    # Increase VMs.
    p "We need to scale!"
    OpenstackHandler.create_vms(VM_CONSTANT)
    state+=1
  elsif state == 1
    # Decrease VMs.
    p "We need to decrease our infrastructure!"
    OpenstackHandler.delete_vms(VM_CONSTANT)
    state+=1
  end
  
  p "Lets wait for 1 min."
  sleep(60) # 1 min
  
  stats = CreamHandler.queue_stats
  p stats
  
end