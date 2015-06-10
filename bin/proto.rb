#!/usr/bin/env ruby

libdir = File.dirname(__FILE__) + '/../lib/'
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require 'awesome_print'
require 'yaml'

require 'aws-cache'
#require 'mstacks'
require 'redis'

host = 'redis.aws.ecnext.net'
port = 6379

keyspace = ARGV[0] || 'debug'
cache = AwsCache.new({'keyspace' => keyspace, 'host' => host, 'port' => port})


output = cache.get_stuff()
output.each do |page|
  page.each do |data|
    ap data.data
  end
end

exit
#puts AwsCache::VERSION
#exit

#active_stacks = Mstacks.new.active_mstacks_hash
#ap active_stacks

#stacks = cache.describe_stacks
#stacks.each do |id, stack|
  #ap stack[:stack_name]
#end
#stacks = cache.list_active_stacks
#stacks = cache.describe_stacks
#ap stacks.first
#stacks.each do |id, stack|
#  ap stack
#  exit
##  #puts stack['stack_status']
#  #puts id
#end

#groups = cache.stack_auto_scaling_groups('manta-site--main--production')
#groups = cache.auto_scaling_groups
#groups.each do |name, group|
#  puts group['auto_scaling_group_name']
#end

#instances = cache.ec2_instances
#ap instances
#instances.each do |id, instance|
#  puts instance['instance_id']
#end

#instances = StackHub::AWSClient.new.instances_for('manta-site--main--production')

#instances = cache.stack_instances('manta-site--main--production')
#ap instances
#instances.each do |id, instance|
#  puts id
#  ap instance[:private_ip_address] #.to_yaml
#  exit
#end

#cache.list_stack_resources('manta-site--main--production')
#stacks = cache.describe_stacks
#ap stacks
#stacks.each_key do |stack_name|
#  resources = cache.list_stack_resources(stack_name)
#  resources.each_key do |logical_resource_id|
#    puts "#{stack_name}:#{logical_resource_id}"
#  end
#end

#stuff = cache.get_snapshots()
#stuff.each_key do |volume|
#  stuff[volume].each do |snapshot|
#    ap snapshot
#  end
#end

#exit
#ap instances
#instances.each do |id, instance|
#  puts id
#  ap instance[:private_ip_address] #.to_yaml
#  exit
#end

exit
