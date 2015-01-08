require 'rspec/expectations'
require 'mkmf'
require_relative '../cream_handler'

# Configuration for Rspec itself
RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end

shared_examples "Invalid path" do |file, method, args|
  it "returns false if the defined path does not exist" do
    if !File.exist?(file)
      false.should == method.call(*args)
    end
  end
end

describe CreamHandler do
  describe "#queue_stats" do
    keys = [:total_jobs, :active_jobs, :idle_jobs, :blocked_jobs, :working_processors, :total_processors, :working_nodes,
            :total_nodes]
    res = true
    model_stats = "
        ACTIVE JOBS--------------------
    JOBNAME            USERNAME      STATE  PROC   REMAINING            STARTTIME

    54 Active Jobs       0 of    0 Processors Active (0.00%)

    IDLE JOBS----------------------
         JOBNAME            USERNAME      STATE  PROC     WCLIMIT            QUEUETIME


    0 Idle Jobs

    BLOCKED JOBS----------------
            JOBNAME            USERNAME      STATE  PROC     WCLIMIT            QUEUETIME


    Total Jobs: 119   Active Jobs: 54   Idle Jobs: 0   Blocked Jobs: 65
    100 of      350 Nodes Active"

    context 'local cream' do
      it "should contain values if cream installed and fail otherwise" do
        cream_local = CreamHandler.new
        if find_executable('showq')
          stats = cream_local.queue_stats
          keys.each { |key|
            res = res && !stats[key].nil?
          }
          true.should == res
        else
          expect {cream_local.queue_status}.to raise_error(Errno::ENOENT::Exception)
        end
      end
    end
    context 'remote cream' do
      context 'connection unsuccessful' do
        it 'should raise NET-SSH exception' do
          cream_remote_not_ok = CreamHandler.new('192.168.35.xx', 'someuser') # recheck on how to make an invalid ip
          session = double(:session)
          expect(Net::SSH).to receive(:start).with('192.168.35.xx', 'someuser').and_yield(session).and_raise(Exception, 'invalid ip')
          expect { cream_remote_not_ok.queue_stats }.to raise_error(Exception)
        end
      end
      end
      context 'connection successful' do
        it 'should contain all values' do
          cream_remote_ok = CreamHandler.new('10.210.123.194', 'ansible')
          session = double(:session)
          expect(Net::SSH).to receive(:start).with('10.210.123.194', 'ansible').and_yield(session)
          expect(session).to receive(:exec!).with('showq').and_return(model_stats)
          stats = cream_remote_ok.queue_stats
          keys.each { |key|
            res = res && !stats[key].nil?
          }
          true.should == res
        end
      end
  end

  describe "#write_to_hosts" do
    mock_etc_hosts_file = '/tmp/mock_etc_hosts_file'
    invalid_path = '/someInvalid/path132.22'
    to_be_written = [ ['1.1.1.1', 'hostname1.domain1.com', 'hostname1'],
                      ['1.1.1.2', 'hostname2.domain1.com', 'hostname2'],
                      ['1.1.1.3', 'hostname3.domain1.com', 'hostname2']
                    ]
    my_cream_handler = CreamHandler.new('localhost')
    context 'local hosts file' do
      before(:all) do
        fake_file = File.new(mock_etc_hosts_file, "w")
        fake_file.close
      end
      it 'should write the hosts to hosts file' do
        my_cream_handler.write_to_hosts(to_be_written, mock_etc_hosts_file)
        etc_hosts_file = File.readlines(mock_etc_hosts_file)
        to_be_written.each { |host|
          expect(etc_hosts_file).to include("#{host.join(' ')}\n")
        }
      end
      it 'should raise Errno::ENOENT if path invalid' do
        expect { my_cream_handler.write_to_hosts(to_be_written, invalid_path) }.to raise_error(Exception)
      end
    end
    context 'remote hosts file' do
      it 'should write the hosts to remote hosts file' do
        # Prepare input
        string_to_append = ""
        to_be_written.each do |ip_name_fqdn|
          string_to_append << "#{ip_name_fqdn.join(' ')}\n"
        end
        my_remote_cream_handler = CreamHandler.new('10.210.123.194', 'ansible')
        session = double(:session)
        expect(Net::SSH).to receive(:start).with('10.210.123.194', 'ansible').and_yield(session)
        expect(session).to receive(:exec!).with("echo -e #{string_to_append} >> #{mock_etc_hosts_file};\
cat #{mock_etc_hosts_file}")
        my_remote_cream_handler.write_to_hosts(to_be_written, mock_etc_hosts_file)
      end
    end
    # include_examples "Invalid path", invalid_path, CreamHandler.method(:write_to_hosts), [ to_be_written, invalid_path ]
    after(:all) do
      File.delete(mock_etc_hosts_file)
    end
  end

  describe "#delete_from_hosts" do
    mock_etc_file = '/tmp/mock_etc_hosts_file'
    invalid_path = '/someInvalid/path132.22'
    fake_file_contents = "1.1.1.1 hostname1.domain1.com hostname1\n\
1.1.1.2 \n\
1.1.1.3 hostname3.domain1.com\n\
1.1.1.4 hostname4.domain2.com hostname4\n"
    to_be_deleted = [ "1.1.1.1", "1.1.1.2", "1.1.1.3" ]
    context 'local hosts file' do
      before(:all) do
        fake_file = File.new(mock_etc_file, 'w')
        fake_file << fake_file_contents
        fake_file.close
      end
      it 'should delete the specified hosts from the hosts file' do
        local_cream_handler = CreamHandler.new('localhost')
        local_cream_handler.delete_from_hosts(to_be_deleted, mock_etc_file)
        etc_hosts_file = File.readlines(mock_etc_file)
        expect(etc_hosts_file).not_to include(*to_be_deleted)
      end
      after(:all) do
        File.delete(mock_etc_file)
      end
    end
    context 'remote hosts file' do
      pending
      it 'should delete the specified hosts from the hosts file' do
        remote_cream_handler = CreamHandler.new('12.210.123.194', 'ansible')
        session = double(:session)
        expect(Net::SSH).to receive(:start).exactly(2).times.and_yield(session)
        expect(session).to receive(:exec!).with("cat #{mock_etc_file}").and_return(fake_file_contents)
        expect(session).to receive(:exec!).and_return("1.1.1.4 hostname4.domain2.com hostname4\n")
        expect(remote_cream_handler.delete_from_hosts(to_be_deleted, mock_etc_file)).to eq(["1.1.1.4 hostname4.domain2.com hostname4\n"])
      end
    end
    # include_examples "Invalid path", invalid_path, CreamHandler.method(:delete_from_hosts), [ to_be_deleted, invalid_path ]
  end

  describe "#add_wns_to_wn_list" do
    mock_wns_file_path = '/tmp/mock_wns_file'
    invalid_path = '/someInvalid/path132.22'
    mock_fqdn_content = "hostname1.domain1.com\nhostname2.domain1.com\nhostname3.domain1.com\n"
    fqdns_to_be_added = [ 'hostname3.domain2.com', 'hostname1.domain10.com', 'hostname1.domain1.com' ]
    context 'local file' do
      before(:all) do
        fake_file = File.new(mock_wns_file_path, 'w')
        fake_file << mock_fqdn_content
        fake_file.close
      end
      local_cream = CreamHandler.new('localhost')
      it "should write the wns to the wn list file" do

        local_cream.add_wns_to_wn_list(fqdns_to_be_added, mock_wns_file_path)
        wns_file_content = File.readlines(mock_wns_file_path)
        fqdns_to_be_added.each do |fqdn|
          expect(wns_file_content).to include("#{fqdn}\n")
        end
      end
      it 'should raise Errno::ENOENT if path invalid' do
        expect { my_cream_handler.add_wns_to_wn_list(fqdns_to_be_added, invalid_path) }.to raise_error(Exception)
      end
      after(:all) do
        File.delete(mock_wns_file_path)
      end
    end
    context 'remote file' do
      it "should write the wns to the wn list" do
        array_to_be_written = mock_fqdn_content.split("\n").concat(fqdns_to_be_added)
        string_to_be_written = array_to_be_written.sort.join("\n")+"\n"


        remote_cream = CreamHandler.new('12.210.123.194', 'ansible')
        session = double(:session)
        expect(Net::SSH).to receive(:start).exactly(2).times.with('12.210.123.194', 'ansible').and_yield(session)
        expect(session).to receive(:exec!).with("cat #{mock_wns_file_path}").and_return(mock_fqdn_content)
        expect(session).to receive(:exec!).with("echo -e #{string_to_be_written}\
 > #{mock_wns_file_path};cat #{mock_wns_file_path}")
        remote_cream.add_wns_to_wn_list(fqdns_to_be_added, mock_wns_file_path)
      end
    end
  end

  describe "#delete_wns_from_wn_list" do
    mock_wns_file_path = '/tmp/mock_wns_file'
    invalid_path = '/someInvalid/path132.22'
    mock_fqdn_content = "hostname1.domain1.com\nhostname2.domain1.com\nhostname3.domain1.com\n"
    fqdns_to_be_deleted = [ 'hostname2.domain1.com', 'hostname3.domain1.com' ]
    context 'local file' do
      before(:all) do
        fake_file = File.new(mock_wns_file_path, 'w')
        fake_file << mock_fqdn_content
        fake_file.close
      end
      it "deletes the wns from the wn_list" do
        local_cream = CreamHandler.new('localhost')
        fileContents = File.readlines(mock_wns_file_path)
        expect(fileContents).not_to include(fqdns_to_be_deleted)
        local_cream.delete_wns_from_wn_list(fqdns_to_be_deleted, mock_wns_file_path)
      end
      after(:all) do
        File.delete(mock_wns_file_path)
      end
    end
    context 'remote file' do
      it "deletes the wns from the wn_list" do
        remote_cream = CreamHandler.new('12.210.123.194', 'ansible')

        fqdns = mock_fqdn_content.split("\n")
        fqdns.reject! {|line| fqdns_to_be_deleted.include? line }

        string_to_be_written = ''
        fqdns.each do |line|
          string_to_be_written << "#{line}\n"
        end

        session = double(:session)
        expect(Net::SSH).to receive(:start).exactly(2).times.with('12.210.123.194', 'ansible').and_yield(session)
        expect(session).to receive(:exec!).with("cat #{mock_wns_file_path}").and_return(mock_fqdn_content)
        expect(session).to receive(:exec!).with("echo -e #{string_to_be_written}\
 > #{mock_wns_file_path};cat #{mock_wns_file_path}")
        remote_cream.delete_wns_from_wn_list(fqdns_to_be_deleted, mock_wns_file_path)
      end
    end
  end

  describe "#restart_yaim!" do
    pending
  end

end