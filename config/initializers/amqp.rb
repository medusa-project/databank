if Rails.env.development?
  amqp_settings_path = File.join(Rails.root, 'config', 'amqp-development.yml')
  amqp_settings = YAML.load(ERB.new(File.read(amqp_settings_path)).result)
elsif Rails.env.test?
  amqp_settings_path = File.join(Rails.root, 'config', 'amqp-ci.yml')
  amqp_settings = YAML.load(ERB.new(File.read(amqp_settings_path)).result)
elsif Application.server_envs.include?(Rails.env)
  amqp_settings_path = File.join(Rails.root, 'config', 'amqp.yml')
  amqp_settings = YAML.load(ERB.new(File.read(amqp_settings_path)).result)[Rails.env]
end

AmqpHelper::Connector.new(:databank, amqp_settings)
