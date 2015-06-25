#!/usr/bin/env ruby

libdir = File.dirname(__FILE__) + '/../lib/'
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require 'awesome_print'
require 'yaml'

require 'aws-cache'
require 'redis'

host = 'redis.aws.ecnext.net'
port = 6379

keyspace = ARGV[0] || 'debug'
cache = AwsCache.new({'keyspace' => keyspace, 'host' => host, 'port' => port})

##############################################################
#To get all instances associated with a given auto scaling group
#you can do something like this.
##############################################################
#placeHolder = Array.new()
#cache.get_asg_instances( "manta-site-e2e-smoketest-AdminServiceNestedStack-1LB9D75MS2SUE-AdminServiceAutoScalingGroup-1I2AY0INI3GH").each do |instances|
#  placeHolder.push(instances[:instance_id])
#end
#cache.describe_instances().each do |instance|
#  instance[:instances].each do |stuff|
#    if placeHolder.include?(stuff[:instance_id]) then
#      ap instance
#    end
#  end
#end
##############################################################

##############################################################
#To get all instances in a stack with substacks do this.
##############################################################
cache.stack_auto_scaling_groups('manta-site--main--production').each do |asg|
  ap cache.get_asg_instances(asg[:physical_resource_id])
end

cache.get_sub_stacks('manta-site--main--production').each do |stack|
  ap stack[:stack_name]
  cache.stack_auto_scaling_groups(stack[:stack_name]).each do |asg|
    ap cache.get_asg_instances(asg[:physical_resource_id])
  end
end
##############################################################

puts AwsCache::VERSION

exit
