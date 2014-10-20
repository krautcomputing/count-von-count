require 'yaml'

module ScriptLoader
  extend self

  attr_accessor :log_player_reads_hash

  def load
    set_config
    load_scripts_to_log_player_test_db if LOG_PLAYER_INTEGRATION
    File.open '/usr/local/openresty/nginx/conf/vars.conf', 'w' do |f|
      f.write "set $redis_counter_hash #{von_count_script_hash};"
    end
    restart_nginx
  end

  def von_count_script_hash
    @von_count_script_hash ||= `redis-cli SCRIPT LOAD "$(cat "lib/redis/voncount.lua")"`.strip
  end

  def load_scripts_to_log_player_test_db
    @log_player_reads_hash ||= `redis-cli -n #{LOG_PLAYER_REDIS_DB} SCRIPT LOAD "$(cat "lib/redis/voncount.lua")"`.strip
  end

  def set_config
    redis = Redis.new(host: HOST, port: 6379)
    config = `cat spec/config/voncount.config | tr -d '\n' | tr -d ' '`
    redis.set 'von_count_config_live', config
  end

  def restart_nginx
    `echo "#{personal_settings['sudo_password']}" | sudo -S nginx -s reload`
    sleep 1
  end

  def clean_access_log
    `rm -f /usr/local/openresty/nginx/logs/access.log`
  end

  def personal_settings
    @@settings ||= YAML.load_file("config/personal.yml") rescue {}
  end
end
