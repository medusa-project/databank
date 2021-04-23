DetectLanguage.configure do |config|
  config.api_key = IDB_CONFIG[:language][:key]

  # enable secure mode (SSL) if you are passing sensitive data
  config.secure = true
end