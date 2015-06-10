require 'redis'
require 'json'
require 'aws-sdk'
require 'yaml'
require 'pry'
require 'aws-cache-version'
require 'awesome_print'

class AwsCache
  # Please follow semantic versioning (semver.org).
  VERSION = AwsCacheVersion::VERSION

  def initialize(opts)
    unless opts.has_key?('port') then opts['port'] = 6379 end
    unless opts.has_key?('host') then opts['host'] = 'aws-cache' end
    @redis = optional_element(opts, ['redis'])
    if @redis.nil?
      @redis = Redis.new(url: "redis://#{opts['host']}:#{opts['port']}/0")
    end
    @keyspace = optional_element(opts, ['keyspace'], AwsCache::VERSION)
    @region = optional_element(opts, ['region'], 'us-east-1')
  end

  def ec2_instances
    instances = cache_get('aws_ec2_instances', 300) do
      instances = {}
    
      ec2 = Aws::EC2::Client.new(region: @region)
      pages = ec2.describe_instances
      pages.each do |page|
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
      if stack_name == optional_element(instance, [:tags,'StackName',:value], '')
        stack_instances[id] = instance
      end
    end
    return stack_instances
  end

  def auto_scaling_groups
    groups = cache_get('aws_auto_scaling_groups', 300) do
      groups = {}
    
      autoscaling = Aws::AutoScaling::Client.new(region: @region)
      pages = autoscaling.describe_auto_scaling_groups
      pages.each do |page|
        page.data[:auto_scaling_groups].each do |group|
	  instances = Hash.new()
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
      if stack_name == optional_element(group, [:tags,'StackName',:value], '')
        stack_groups[name] = group
      end
    end
    return stack_groups
  end

  def describe_stacks
    cloudformation_stacks = cache_get('aws_cloudformation_describe_stacks', 3 ) do
      cloudformation_stacks = {}
    
      cfn = Aws::CloudFormation::Client.new(region: @region)
      pages = cfn.describe_stacks
      ap pages
      pages.each do |page|
        ap page
        exit
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

      pages = cfn.list_stack_resources(stack_name: stack_name)
      pages.each do |page|
        resources = page.data[:stack_resource_summaries]
	resources.each do |resource|
	  stack_resources[resource[:logical_resource_id]] = resource
	end
      end
    
      stack_resources
    end

    return stack_resources
  end

  def get_stacks()
    output = cache_get_2('get_stacks', 300) do
      aws_object = Aws::CloudFormation::Client.new(region: @region)
      pages = aws_object.list_stacks
      output = process_page( 'stack_summaries', pages)
    end
    return output
  end

  def get_snapshots()
    output = cache_get_2('get_snapshots', 300) do
      aws_object = Aws::EC2::Client.new(region: 'us-east-1')
      pages = aws_object.describe_snapshots
      output = process_page( 'snapshots', pages)
    end
    return output
  end

  def get_autoscaling_groups()
    output = cache_get_2('get_autoscaling_groups', 300) do
      aws_object = Aws::AutoScaling::Client.new(region: 'us-east-1')
      pages = aws_object.describe_auto_scaling_groups
      output = process_page( 'auto_scaling_groups', pages)
    end
    return output
  end

  def process_page( key, pages)
    output = Array.new()
    pages.each do |page|
      page.each do |data|
        data.data[key].each do |entry|
          output.push(entry)
        end
      end
    end
    return output
  end

  private
  def optional_element(hash, keys, default=nil)
    keys.each do |key|
      if !has_key?(hash, key)
	return default
      end
      hash = hash[key]
    end
    return hash 
  end

  def has_key?(hash_or_struct, key)
    hos = hash_or_struct
    if hos.is_a?(Hash) && hos.has_key?(key)
      return true
    end
    if hos.is_a?(Struct) && hos.members.any? { |m| m == key }
      return true
    end
    return false
  end

  def cache_get_2(key, ttl)
    vkey = "#{key}_#{@keyspace}"
    output = @redis.get(vkey)
    if output.nil?
      print "Did not return results from cache\n"
      output = yield
      output = YAML.dump(output)
      @redis.setex(vkey, ttl, output )
    else
      print "Did return results from cache\n"
    end
    return YAML.load(output)
  end


  def cache_get(key, ttl)
    vkey = "#{key}_#{@keyspace}"
    hash = @redis.get(vkey)
    ap hash.class.name
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
