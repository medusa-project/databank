namespace :box do
  desc "Expire abandoned Box imports and remove temporary credentials"
  task cleanup: :environment do
    BoxImport.cleanup_expired!
  end
end
