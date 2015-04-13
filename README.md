# aws-cache

[![Build Status](https://travis-ci.org/mantacode/aws-cache.png?branch=master)](https://travis-ci.org/mantacode/aws-cache)

## Why

We have many monitoring and management utilities that rely on knowing the state of our aws infrastructure--instances, cloudformation stacks, autoscaling groups, etc. After we wrote a few of these we started running into api throttling exceptions because these utilities were making an excessive number of api calls. We realized that in most cases these utilities did not require up-to-the-second information, so this module provides a wrapper api that works by caching information on our entire infrastructure in Redis and updating the cache every few minutes.

## Usage

```
require 'aws-cache'
cache = AwsCache.new({'version' => version})
instances = cache.ec2_instances
```

## Development

Improvements welcome.

### Build gem file

```
$ gem build aws-cache.gemspec
```

## Requirements

 - ruby 1.9+
 - aws-sdk v2
 - redis

Known to work on OSX and Ubuntu.

### Legal

aws-cache was created by [Manta Media Inc](http://www.manta.com/), a web
company in Columbus, Ohio. It is distributed under the MIT license.
