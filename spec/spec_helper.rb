require 'open-uri'
require 'script_loader'
require 'rubygems'
require 'redis'
require 'json'
require 'support/redis_object_factory'
require "integration/log_player_integrator"

HOST = "127.0.0.1"

def spec_config
  @spec_config ||= YAML.load_file('spec/config/spec_config.yml') rescue {}
end

spec_config["redis_port"]
lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

$redis = Redis.new(host: spec_config["redis_host"], port: spec_config["redis_port"], db: spec_config["redis_db"])
$log_player_redis = Redis.new(host: HOST, port: spec_config["redis_port"] , db: spec_config["log_player_redis_db"])
ScriptLoader.load
RedisObjectFactory.redis = $redis

def create(type, ids = nil)
  ids ||= { id: rand(1000000) }
  RedisObjectFactory.new(type, ids)
end

