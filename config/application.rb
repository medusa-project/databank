require_relative 'boot'

require 'rails/all'

Bundler.require(*Rails.groups)

module Databank

  # file means all files only
  # metadata means all files + metadata
  # TempSuppress states should be able to stack with other states
  # Most restrictive state is effective

  class PublicationState
    DRAFT = 'draft'
    RELEASED = 'released'
    class Embargo
      NONE = 'none'
      FILE = 'file embargo'
      METADATA = 'metadata embargo'
    end
    class TempSuppress
      NONE = 'none'
      FILE = 'files temporarily suppressed'
      METADATA = 'metadata temporarily suppressed'
      VERSION = 'version candidate under curator review'
    end
    class PermSuppress
      FILE = 'files permanently suppressed'
      METADATA = 'metadata permanently suppressed'
    end
    PUB_ARRAY = [Databank::PublicationState::RELEASED, Databank::PublicationState::Embargo::FILE, Databank::PublicationState::Embargo::METADATA]
    EMBARGO_ARRAY = [Databank::PublicationState::Embargo::FILE, Databank::PublicationState::Embargo::METADATA]
    DRAFT_ARRAY = [Databank::PublicationState::DRAFT, Databank::PublicationState::TempSuppress::VERSION]
  end

  class FileMode
    WRITE_READ = 'rw'
    READ_ONLY = 'ro'
  end

  class Relationship
    SUPPLEMENT_TO = 'IsSupplementTo'
    SUPPLEMENTED_BY = 'IsSupplementedBy'
    CITED_BY = 'IsCitedBy'
    PREVIOUS_VERSION_OF = 'IsPreviousVersionOf'
    NEW_VERSION_OF = 'IsNewVersionOf'
  end

  class MaterialType
    ARTICLE = 'Article'
    CODE = 'Code'
    DATASET = 'Dataset'
    PRESENTATION = 'Presentation'
    THESIS = 'Thesis'
    OTHER = 'Other'
  end

  class Subject
    NONE = ''
    PHYSICAL_SCIENCES = 'Physical Sciences'
    LIFE_SCIENCES = 'Life Sciences'
    SOCIAL_SCIENCES = 'Social Sciences'
    TECHNOLOGY_ENGINEERING = 'Technology and Engineering'
    ARTS_HUMANITIES = 'Arts and Humanities'
  end

  class TaskStatus
    PENDING = 'pending'
    PROCESSING = 'processing'
    ERROR = 'error'
    RIPE = 'ripe'
    HARVESTING = 'harvesting'
    HARVESTED = 'harvested'
  end

  class ProblemStatus
    REPORTED = 'reported'
    EXAMINED = 'examined'
    RESOLVED = 'resolved'
  end

  class PeekType
    ALL_TEXT = 'all_text'
    PART_TEXT = 'part_text'
    IMAGE = 'image'
    MICROSOFT = 'microsoft'
    PDF = 'pdf'
    LISTING = 'listing'
    MARKDOWN = 'markdown'
    BLOCKED = 'blocked'
    NONE = 'none'
  end

  class CreatorType
    PERSON = 0
    INSTITUTION = 1
  end

  class UserRole
    ADMIN = 'admin'
    DEPOSITOR = 'depositor'
    GUEST = 'guest'
    NO_DEPOSIT = 'no_deposit'
    NETWORK_REVIEWER = 'network_reviewer'
    PUBLISHER_REVIEWER = 'publisher_reviewer'
    CREATOR = 'creator'
  end

  class DoiEvent
    PUBLISH = "publish"
    REGISTER = "register"
    HIDE = "hide"
  end

  class DoiAction
    CREATE = "create"
    DELETE = "delete"
  end

  class DoiState
    UNREGISTERED = 'unregistered'
    DRAFT = 'draft'
    REGISTERED = 'registered'
    FINDABLE = 'findable'
  end

  class ExtractionStatus
    ERROR = 'error'
    SUCCESS = 'success'
  end

  class HelpTransitionState
    HELP = 'help'
    GUIDE = 'guide'
    BOTH = 'both'
    COLLECTION = %w[help guide both]
  end

  class FileChangeType
    ADDED = 'added'
    DELETED = 'deleted'
  end

  class ReportType
    FILE_AUDIT = 'file_audit'
  end

  class ReportStatus
    PENDING = 'pending'
    GENERATING = 'generating'
    AVAILABLE = 'available'
  end

  class Application < Rails::Application

    attr_accessor :shibboleth_host

    attr_accessor :file_mode

    attr_accessor :settings

    attr_accessor :ldap

    attr_accessor :markdown

    attr_accessor :aws_signer

    attr_accessor :aws_client

    attr_accessor :server_envs

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    config.load_defaults "7.1"
    config.action_controller.raise_on_open_redirects = false
    config.active_job.queue_adapter = :delayed_job
    config.generators.javascript_engine = :js
    config.active_record.use_yaml_unsafe_load = true
  end
end

#establish a short cut for the Application object
Application = Databank::Application