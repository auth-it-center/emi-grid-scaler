require 'bundler/setup'
require_relative 'scaler_config.rb'

task :default => :load_gems

desc "Load the necessary gems into the project"
task :load_gems do
  Bundler.with_clean_env do
    sh "bundle install"
  end
end

desc "Show configurations"
task :show_config do
  p "Debug mode: #{ScalerConfig.debug}"
  p "Debug OpenStack: #{ScalerConfig.debug_openstack}"
  p "Local cream" if ScalerConfig.cream_local
  p "Flavor id: #{ScalerConfig.flavor_id}"
  p "Image id: #{ScalerConfig.image_id}"
end

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  # no rspec available
end