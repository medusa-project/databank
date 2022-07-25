require 'rake'
namespace :pub do

  desc 'update publication state for datasets with current or past release date'
  task :update_state => :environment do

    @current_user = User::User.system_user

    Dataset.all.each do |dataset|

      dataset.release_date = Date.current() unless dataset.release_date

      if [Databank::PublicationState::Embargo::METADATA, Databank::PublicationState::Embargo::FILE].include?(dataset.publication_state) && dataset.release_date <= Date.current()
        dataset.publication_state = Databank::PublicationState::RELEASED
        dataset.embargo = Databank::PublicationState::Embargo::NONE
        dataset.save
        dataset.publish_doi
      end
    end
  end

end