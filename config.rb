class Config
  
  # attr_accessor :debug, :debug_openstack
  # attr_accessor :cream_local
  # 
  # attr_accessor :flavor_id, :image_id
  
  @@debug = false
  @@debug_openstack = false
  @@cream_local = true
  
  @@flavor_id = 3
  @@image_id = 50
  
  def self.debug=(debug)
    @@debug = debug
  end
  
  def self.debug
    @@debug
  end
  
  def self.debug_openstack=(debug_openstack)
    @@debug_openstack = debug_openstack
  end
  
  def self.debug_openstack
    @@debug_openstack
  end
  
  def self.cream_local=(cream_local)
    @@cream_local = cream_local
  end
  
  def self.cream_local
    @@cream_local
  end

  def self.flavor_id=(flavor_id)
    @@flavor_id = flavor_id
  end
  
  def self.flavor_id
    @@flavor_id
  end

  def self.image_id=(image_id)
    @@image_id = image_id
  end
  
  def self.image_id
    @@image_id
  end  
end