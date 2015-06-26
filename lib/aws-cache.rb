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

  def describe_instance( instance_id)
    instances = self.describe_instances()
    instances.each do |instance|
      ap instance
      if instance[:instances][0] == instance_id then
        ap instance[:instances][0]
      end
    end
    return instances
  end

  def stack_auto_scaling_groups(stack_name)
    autoscaling_groups = Array.new()
    output = self.list_stack_resources(stack_name)
    output.each do |entry|
      if entry[:resource_type] == "AWS::AutoScaling::AutoScalingGroup"
        autoscaling_groups.push(entry)
      end
    end
    return autoscaling_groups
  end

  def list_stack_resources( stack_name)
    output = cache_get_2("list_stack_resources-#{stack_name}", 300) do
      aws_object = Aws::CloudFormation::Client.new(region: @region)
      pages = aws_object.list_stack_resources(stack_name: stack_name)
      output = process_page( 'stack_resource_summaries', pages)
    end
    return output
  end


  def get_sub_stacks( stack_name)
    substacks = Array.new()
    stacks = self.list_stack_resources(stack_name)
    stacks.each do |entry|
      if entry[:resource_type] == "AWS::CloudFormation::Stack"
        self.describe_stacks.each do |stack|
          if entry[:physical_resource_id] == stack[:stack_id]
            substacks.push(stack)
          end
        end
      end
    end
    return substacks
  end
        
  def describe_stack(stack_name)
    stacks = self.describe_stacks
    stacks.each do |stack|
      if stack[:stack_name] == stack_name
        return stack
      end
    end
    return nil
  end

  def describe_stacks()
    output = cache_get_2('get_stacks', 300) do
      aws_object = Aws::CloudFormation::Client.new(region: @region)
      pages = aws_object.describe_stacks
      output = process_page( 'stacks', pages)
    end
    return output
  end

  def describe_snapshots()
    output = cache_get_2('get_snapshots', 300) do
      aws_object = Aws::EC2::Client.new(region: @region)
      pages = aws_object.describe_snapshots
      output = process_page( 'snapshots', pages)
    end
    return output
  end

  def get_asg_instances(asg)
    instances = Array.new()
    asg = self.describe_auto_scaling_group(asg)
    asg[:instances].each do |instance|
      instances.push(instance)
    end
    return instances
  end

  def describe_auto_scaling_group(asg)
    asgroups = self.describe_autoscaling_groups()
    asgroups.each do |asgroup|
      if asgroup[:auto_scaling_group_name] == asg then
        return asgroup
      end
    end
    return nil
  end

  def describe_autoscaling_groups()
    output = cache_get_2('get_autoscaling_groups', 300) do
      aws_object = Aws::AutoScaling::Client.new(region: @region) 
      pages = aws_object.describe_auto_scaling_groups
      output = process_page( 'auto_scaling_groups', pages)
    end
    return output
  end

  def describe_instances()
    output = cache_get_2('describe_instances', 300) do
      aws_object = Aws::EC2::Client.new(region: @region)
      pages = aws_object.describe_instances
      output = process_page( 'reservations', pages)
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
      output = yield
      output = YAML.dump(output)
      @redis.setex(vkey, ttl, output )
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
