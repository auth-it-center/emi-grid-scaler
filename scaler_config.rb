require_relative 'cream_handler'
require_relative 'openstack_handler'

class ScalerConfig

  # Default values
  # debug_cream true
  # debug_openstack true
  # flavor_id 3
  # image_id 50

  def self.debug_all=(debug)
    self.debug_cream= debug
    self.debug_openstack= debug
  end

  def self.debug_cream=(debug)
    CreamHandler.debug= debug
  end
  
  def self.debug_cream
    CreamHandler.debug
  end
  
  def self.debug_openstack=(debug_openstack)
    OpenstackHandler.debug= debug_openstack
  end
  
  def self.debug_openstack
    OpenstackHandler.debug
  end
  
  def self.cream_local=(cream_local)
    CreamHandler.cream_local= cream_local
  end
  
  def self.cream_local
    CreamHandler.creamLocal
  end

  def self.flavor_id=(flavor_id)
    OpenstackHandler.flavor_id= flavor_id
  end
  
  def self.flavor_id
    OpenstackHandler.flavor_id
  end

  def self.image_id=(image_id)
    OpenstackHandler.image_id= image_id
  end
  
  def self.image_id
    OpenstackHandler.image_id
  end  
end