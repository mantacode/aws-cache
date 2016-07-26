require 'redis'
require 'aws-sdk'
require 'yaml'
require 'aws-cache/version'

class AwsCache
  def initialize(opts)
    opts['port'] = 6379 unless opts.key?('port')
    opts['host'] = 'aws-cache' unless opts.key?('host')
    @redis = optional_element(opts, ['redis'])
    if @redis.nil?
      @redis = Redis.new(url: "redis://#{opts['host']}:#{opts['port']}/0")
    end
    @keyspace = optional_element(opts, ['keyspace'], AwsCache::VERSION)
    @region = optional_element(opts, ['region'], 'us-east-1')
  end

  # Returns a hash describing the instance requested.
  def describe_instance(instance_id)
    instances = describe_instances
    instance = instances.select do |entry|
      entry[:instances][0][:instance_id] == instance_id
    end
    instance[0]
  end

  # Returns an array of hashes describing the autoscaling groups for the selected stack.
  def stack_auto_scaling_groups(stack_name)
    auto_scaling_groups = []
    stack_resources = list_stack_resources(stack_name)
    asg_groups = stack_resources.select do |record|
      record[:resource_type] == 'AWS::AutoScaling::AutoScalingGroup'
    end
    auto_scaling_groups.concat(asg_groups)
    substacks = stack_resources.select do |record|
      record[:resource_type] == 'AWS::CloudFormation::Stack'
    end
    unless substacks.empty?
      substacks.each do |stack|
        auto_scaling_groups.concat(stack_auto_scaling_groups(stack[:physical_resource_id]))
      end
    end
    auto_scaling_groups
  end

  # Returns an array of hashes describing the substacks for the selected stack.
  def get_sub_stacks(stack_name)
    substacks = []
    stacks = list_stack_resources(stack_name)
    stacks.each do |entry|
      next unless entry[:resource_type] == 'AWS::CloudFormation::Stack'
      describe_stacks.each do |stack|
        if entry[:physical_resource_id] == stack[:stack_id]
          substacks.push(stack)
        end
      end
    end
    substacks
  end

  # Returns a hash describing the stack requested.
  def describe_stack(stack_name)
    stacks = describe_stacks
    stacks.each do |stack|
      return stack if stack[:stack_name] == stack_name
    end
    nil
  end

  # Returns an array of hashes of instances.
  def get_asg_instances(asg)
    instances = []
    asg_instances = describe_auto_scaling_group(asg)
    asg_instances[:instances].each do |instance|
      instances.push(instance)
    end
    instances
  end

  # Returns Aws::AutoScaling::Types::AutoScalingGroup
  def describe_auto_scaling_group(asg)
    asgroups = describe_autoscaling_groups
    target_asg = asgroups.select do |record|
      record[:auto_scaling_group_name] == asg
    end
    return target_asg[0] if target_asg
    nil
  end

  def describe_snapshots
    output = cache_get('get_snapshots', 300) do
      aws_object = Aws::EC2::Client.new(region: @region)
      pages = aws_object.describe_snapshots
      output = process_page('snapshots', pages)
    end
    output
  end

  def list_stack_resources(stack_name)
    output = cache_get("list_stack_resources-#{stack_name}", 300) do
      aws_object = Aws::CloudFormation::Client.new(region: @region)
      pages = aws_object.list_stack_resources(stack_name: stack_name)
      output = process_page('stack_resource_summaries', pages)
    end
    output
  end

  def describe_stacks
    output = cache_get('get_stacks', 300) do
      aws_object = Aws::CloudFormation::Client.new(region: @region)
      pages = aws_object.describe_stacks
      output = process_page('stacks', pages)
    end
    output
  end

  def describe_auto_scaling_instances
    output = cache_get('describe_auto_scaling_instances', 300) do
      aws_object = Aws::AutoScaling::Client.new(region: @region)
      pages = aws_object.describe_auto_scaling_instances
      output = process_page('auto_scaling_instances', pages)
    end
    output
  end

  # Returns an Array of Hashes containing auto scaling group structures
  def describe_autoscaling_groups
    output = cache_get('get_autoscaling_groups', 300) do
      aws_object = Aws::AutoScaling::Client.new(region: @region)
      pages = aws_object.describe_auto_scaling_groups
      output = process_page('auto_scaling_groups', pages)
    end
    output
  end

  # Returns an Array of Hashes containing instance structures
  def describe_instances
    output = cache_get('describe_instances', 300) do
      aws_object = Aws::EC2::Client.new(region: @region)
      pages = aws_object.describe_instances
      output = process_page('reservations', pages)
    end
    output
  end

  def process_page(key, pages)
    output = []
    pages.each do |page|
      data = page.send(key)
      data.each do |asg|
        output.push(asg)
      end
    end
    output
  end

  private

  def optional_element(hash, keys, default = nil)
    keys.each do |key|
      return default unless key?(hash, key)
      hash = hash[key]
    end
    hash
  end

  def key?(hash_or_struct, key)
    hos = hash_or_struct
    return true if hos.is_a?(Hash) && hos.key?(key)
    return true if hos.is_a?(Struct) && hos.members.any? { |m| m == key }
    false
  end

  def cache_get(key, ttl)
    vkey = "#{key}_#{@keyspace}"
    output = @redis.get(vkey)
    if output.nil?
      output = yield
      output = Psych.dump(output)
      @redis.setex(vkey, ttl, output)
    end
    Psych.load(output)
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
