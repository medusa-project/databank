amqp_settings_path = File.join(Rails.root, 'config', 'amqp.yml')
amqp_settings = YAML.load(ERB.new(File.read(amqp_settings_path)).result)[Rails.env]

AmqpHelper::Connector.new(:databank, amqp_settings)
