os = nil
servers = nil
image = nil
flavor = nil
newservers = []

flag = true

p "======================================================"
p "======================================================"
p "             Information from OpenStack.              "
p "======================================================"

  
# Create the client to connect to OpenStack.
p "Create the client to connect to OpenStack."
retryable(:tries => 3, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
  os = OpenStack::Connection.create({:username => "cream", 
                                    :api_key=>"cream", 
                                    :auth_url => "http://192.168.124.81:5000/v1.1/", 
                                    :authtenant_name =>"scc-61", 
                                    :is_debug => true})
  p "OK"
end

# Get all running servers.
p "Get all running servers."
retryable(:tries => 3, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
  servers = os.servers
  p "OK"
end

p "Number of servers = #{servers.count}"

server_ids = servers.collect { |server| server[:id] }

if server_ids.count == 0
  p "======================================================"
  p "======================================================"
  
  # Get the image ref.
  p "Get the image ref."
  retryable(:tries => 3, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
    image = os.get_image(3)
    p "OK"
  end                      

  # Get the flavor ref.
  p "Get the flavor ref."
  retryable(:tries => 3, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
    flavor = os.get_flavor(1)
    p "OK"
  end                      
  
  p "======================================================"
  p "======================================================"
  
  # Create 3 new servers.
  p "Create 3 new servers."
  3.times do |counter|
    retryable(:tries => 3, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
      newservers << os.create_server(:name => "New Tasos Server #{counter}", :imageRef => image.id, :flavorRef => flavor.id)
    end
    sleep(1)
    p "OK for #{counter}"
  end                      
end

# Print the status of all servers. This must be BUILD for first iteration.
p "Print the status of all servers. This must be BUILD for first iteration."
newservers.each { |server| p server.status }

# We will refresh and see the status again. We will continue when we have all VMs ACTIVE.
p "We will refresh and see the status again. We will continue when we have all VMs ACTIVE."

while flag
  p "===== Server refreshing ====="
  newservers.each do |server| 
    retryable(:tries => 3, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
      server.refresh
      p "OK"
    end
  end

  newservers.each { |server| p server.status }
  
  server_status = newservers.collect { |server| server.status }
  
  i = 0
  server_status.each { |s| if s == "ACTIVE" then i+=1 end }
  if i == server_status.count
    flag = false
  end
  
  sleep(10)
end

p "======================================================"
p "======================================================"
p "======================================================"
p "======================================================"

# We will delete all the servers.
p "We will delete all the servers."
newservers.each do |server|
  retryable(:tries => 3, :sleep => 2, :on => OpenStack::Exception::Other) do
    server.delete!
    p "OK"
  end
end

# Check if all servers have been deleted.
p "Check if all servers have been deleted."
begin 
  p "Reading servers."

  retryable(:tries => 3, :sleep => 2, :on => [OpenStack::Exception::Other, OpenStack::Exception::BadRequest]) do
    servers = os.servers
    p "OK"
  end
  
  p "Number of servers = #{servers.count}"
  sleep(10)
end while servers.count > 0



os = OpenStack::Connection.create({:username => "cream", 
                                  :api_key=>"cream", 
                                  :auth_url => "http://192.168.124.81:5000/v2.0/", 
                                  :authtenant_name =>"scc-141",
                                  :is_debug => true})
image = os.get_image(3)
flavor = os.get_flavor(1)
s = os.create_server(:name => "New Tasos Server2", :imageRef => image.id, :flavorRef => flavor.id)


########### NOTES ############
# require "../../Xcode\ Files/github/ruby-openstack/lib/openstack"

# a = %x[curl -sS -H 'Content-Type: application/json' -d '{"auth": {"tenantName": "scc-62", "passwordCredentials": {"username": "cream", "password": "cream"}}}' http://192.168.124.81:5000/v2.0/tokens]

# curl -sS -H 'Content-Type: application/json' -d '{"auth": {"tenantName": "scc-62", "passwordCredentials": {"username": "cream", "password": "cream"}}}' http://192.168.124.81:5000/v2.0/tokens | python -m json.tool

# curl -v -X POST -H "X-Auth-Token:999888777666" -H "Content-type:application/json" -d '{"server": {"flavorRef": "http://localhost:8774/v1.1/openstack/flavors/1", "personality": [{"path": "", "contents": ""}], "name": "tornado001", "imageRef": "http://localhost:8774/v1.1/openstack/images/1", "metadata": {"Server Name": "Tornado"}}}' http://localhost:8774/v1.1/openstack/servers