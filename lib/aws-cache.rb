require 'redis'
require 'json'
require 'aws-sdk'
require 'yaml'

class AwsCache
  # Please follow semantic versioning (semver.org).
  VERSION = '0.0.1'

  def initialize(opts)
    @redis = optional_element(opts, ['redis'])
    if @redis.nil?
      @redis = Redis.new(url: 'redis://aws-cache:6379/0')
    end
    @keyspace = optional_element(opts, ['keyspace'], AwsCache::VERSION)
    @region = optional_element(opts, ['region'], 'us-east-1')
  end

  def ec2_instances
    instances = cache_get('aws_ec2_instances', 300) do
      instances = {}
    
      ec2 = Aws::EC2::Client.new(region: @region)
      page = ec2.describe_instances
      page.each do |page|
	page = 
        page.data[:reservations].each do |res|
          res[:instances].each do |instance|
	    list_to_hash!(instance, [:tags], :key)
	    list_to_hash!(instance, [:block_device_mappings], :device_name)
	    instances[instance[:instance_id]] = instance
	  end
	end
      end
    
      instances
    end

    return instances
  end

  def stack_instances(stack_name)
    instances = self.ec2_instances
    stack_instances = {}
    instances.each do |id, instance|
      if stack_name == optional_element(instance, [':tags','StackName',':value'], '')
        stack_instances[id] = instance
      end
    end
    return stack_instances
  end

  def auto_scaling_groups
    groups = cache_get('aws_auto_scaling_groups', 300) do
      groups = {}
    
      autoscaling = Aws::AutoScaling::Client.new(region: @region)
      page = autoscaling.describe_auto_scaling_groups
      page.each do |page|
        page.data[:auto_scaling_groups].each do |group|
	  instances = {}
	  list_to_hash!(group, [:instances], :instance_id)
	  list_to_hash!(group, [:tags], :key)
	  groups[group[:auto_scaling_group_name]] = group
	end
      end
    
      groups
    end

    return groups
  end

  def stack_auto_scaling_groups(stack_name)
    groups = self.auto_scaling_groups
    stack_groups = {}
    groups.each do |name, group|
      if stack_name == optional_element(group, [':tags','StackName',':value'], '')
        stack_groups[name] = group
      end
    end
    return stack_groups
  end

  def describe_stacks
    cloudformation_stacks = cache_get('aws_cloudformation_describe_stacks', 900) do
      cloudformation_stacks = {}
    
      cfn = Aws::CloudFormation::Client.new(region: @region)
      page = cfn.describe_stacks
      page.each do |page|
        page.data[:stacks].each do |stack|
	  list_to_hash!(stack, [:parameters], :parameter_key)
	  list_to_hash!(stack, [:outputs], :output_key)
	  list_to_hash!(stack, [:tags], :key)
	  cloudformation_stacks[stack[:stack_name]] = stack
	end
      end
    
      cloudformation_stacks
    end

    return cloudformation_stacks
  end

  def describe_stack(stack_name)
    stacks = self.describe_stacks
    return stacks[stack_name]
  end

  def list_stack_resources(stack_name)
    stack_resources = cache_get("aws_cloudformation_list_stack_resources:#{stack_name}", 900) do
      stack_resources = {}
      cfn = Aws::CloudFormation::Client.new(region: @region)

      page = cfn.list_stack_resources(stack_name: stack_name)
      page.each do |page|
        resources = page.data[:stack_resource_summaries]
	resources.each do |resource|
	  stack_resources[resource[:logical_resource_id]] = resource
	end
      end
    
      stack_resources
    end

    return stack_resources
  end

  # One way this is different than describe_stacks is that it includes
  # deleted stacks.
  def list_stacks
    stacks = cache_get('aws_cloudformation_list_stacks', 900) do
      # Can't return a hash, because some stacks will appear more
      # than once, such as if the stack was deleted and recreated.
      stacks = []
    
      cfn = Aws::CloudFormation::Client.new(region: @region)
      page = cfn.list_stacks
      page.each do |page|
        page.data[:stack_summaries].each do |stack|
	  stacks.push(stack)
	end
      end
    
      stacks
    end

    return stacks
  end

  private
  def optional_element(hash, keys, default=nil)
    keys.each do |key|
      if !hash.is_a?(Hash) || !hash.has_key?(key)
	return default
      end
      hash = hash[key]
    end
    return hash 
  end

  def cache_get(key, ttl)
    vkey = "#{key}_#{@keyspace}"
    hash = @redis.get(vkey)
puts hash
    unless hash.nil?
      hash = YAML.load(hash)
    end

    if hash.nil?
      hash = yield

      hash = hash.to_yaml
      @redis.setex(vkey, ttl, hash)
      hash = YAML.load(hash)
    end

    return hash
  end

  def list_to_hash!(src, keys, by_key)
    hash = {}
    last_key = keys.pop
    keys.each do |key|
      src = src[key]
    end
    src[last_key].each do |entry|
      hash[entry[by_key]] = entry
    end
    src[last_key] = hash
  end
end
