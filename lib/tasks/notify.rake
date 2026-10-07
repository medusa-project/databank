require 'rake'
require 'date'

namespace :notify do

  desc 'send all incomplete dataset 1 month alerts'
  task :send_incomplete_1m_all => :environment do
    # do nothing, but leave the task defined until the cron job is corrected
    # This task is temporarily disabled.
    nil
  end

  desc 'send all approaching embargo 1 month alerts'
  task :send_embargo_approaching_1m_all => :environment do
    Dataset.all.each do |dataset|
      if ([Databank::PublicationState::Embargo::FILE, Databank::PublicationState, Databank::PublicationState::Embargo::METADATA].include?(dataset.publication_state)) && (dataset.release_date.to_date == 1.month.from_now.to_date)
        dataset.send_embargo_approaching_1m
      end
    end
  end

  desc 'send all approaching embargo 1 week alerts'
  task :send_embargo_approaching_1w_all => :environment do
    Dataset.all.each do |dataset|
      if ([Databank::PublicationState::Embargo::FILE, Databank::PublicationState, Databank::PublicationState::Embargo::METADATA].include?(dataset.publication_state)) && (dataset.release_date.to_date == 1.week.from_now.to_date)
        dataset.send_embargo_approaching_1w
      end
    end
  end

end