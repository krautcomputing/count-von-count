require 'open-uri'
require 'script_loader'
require 'redis'

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require f }

HOST                   = '127.0.0.1'
REDIS_HOST             = '127.0.0.1'
REDIS_PORT             = 6379
REDIS_DB               = 0
LOG_PLAYER_INTEGRATION = false
LOG_PLAYER_REDIS_DB    = 1

# lib = File.expand_path('../../lib', __FILE__)
# $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

$redis = Redis.new(host: REDIS_HOST, port: REDIS_PORT, db: REDIS_DB)
$log_player_redis = Redis.new(host: HOST, port: REDIS_PORT , db: LOG_PLAYER_REDIS_DB)

ScriptLoader.load
RedisObjectFactory.redis = $redis

def create(type, ids = nil)
  ids ||= { id: rand(1000000) }
  RedisObjectFactory.new(type, ids)
end

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'

  if LOG_PLAYER_INTEGRATION
    config.before :all do
      flush_keys
      ScriptLoader.clean_access_log
      ScriptLoader.restart_nginx
    end

    config.after :all do
      compare_log_player_values_to_real_time_values
    end
  end

end

def compare_log_player_values_to_real_time_values
  run_log_player
  $redis.keys.each do |key|
    if !unrelevant_keys.include?(key)
      if !compare_value(key)
        raise RSpec::Expectations::ExpectationNotMetError, "Log Player Intregration: difference in #{key}"
      end
    end
  end
end

def flush_keys
  [$redis, $log_player_redis].each do |redis|
    cache_keys = redis.keys('*').reject { |key| key =~ /^von_count_config/ }
    redis.del cache_keys if cache_keys.any?
  end
end

def unrelevant_keys
  %w(von_count_config_live)
end

def compare_value(key)
  case $redis.type(key)
  when 'hash'
    $redis.hgetall(key) == $log_player_redis.hgetall(key)
  when 'zset'
    $redis.zrevrange(key, 0, -1, withscores: true) == $log_player_redis.zrevrange(key, 0, -1, withscores: true)
  when 'string'
    $redis.get(key) == $log_player_redis.get(key)
  else
    false
  end
end

def run_log_player
  `lua \
    /usr/local/openresty/nginx/count-von-count/lib/log_player.lua \
    /usr/local/openresty/nginx/logs/access.log \
    #{REDIS_HOST} \
    #{REDIS_PORT} \
    #{LOG_PLAYER_REDIS_DB}
  `
end
