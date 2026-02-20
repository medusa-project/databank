# frozen_string_literal: true

##
# Defines and sends email notifications for the Illinois Data Bank application.
# It is used to send email notifications to users and administrators.
require "open-uri"
require "open_uri_redirections"

class DatabankMailer < ActionMailer::Base
  default from: IDB_CONFIG[:admin][:contact_email]

  ##
  # Sends an email to the depositor and the curators for use when a new version is approved.
  # The email is sent to the depositor and the admin.
  # @param dataset_key [String] the key of the dataset
  def approve_version(dataset_key:)
    @dataset = Dataset.find_by(key: dataset_key)
    subject_base = "Illinois Data Bank] New Version Request Approved"
    subject = prepend_system_code(subject_base)
    mail(to: @dataset.depositor_email,
         cc: IDB_CONFIG[:admin][:contact_email],
         subject: subject)
  end

  ##
  # Sends an email to the curators for use when a new version is requested.
  # @param dataset_key [String] the key of the dataset
  def request_version(dataset_key:)
    @dataset = Dataset.find_by(key: dataset_key)
    subject_base = "Illinois Data Bank] Version Request"
    subject = prepend_system_code(subject_base)
    mail(to:      IDB_CONFIG[:admin][:contact_email],
         subject: subject)
  end

  ##
  # Sends an email to the curators for use when requested files for a new version is copied.
  # @param dataset_key [String] the key of the dataset
  def notify_version_copy_complete(dataset_key:)
    @dataset = Dataset.find_by(key: dataset_key)
    subject_base = "Illinois Data Bank] Version Copy Complete"
    subject = prepend_system_code(subject_base)
    mail(to:      IDB_CONFIG[:admin][:contact_email],
         subject: subject)
  end

  ##
  # Sends an email to the depositor (and copies curators) for use when a new version is requested.
  # @param dataset_key [String] the key of the dataset
  def acknowledge_request_version(dataset_key:)
    @dataset = Dataset.find_by(key: dataset_key)
    subject_base = "Illinois Data Bank] Version Request Acknowledgement"
    subject = prepend_system_code(subject_base)
    mail(to:      @dataset.depositor_email,
         cc:      IDB_CONFIG[:admin][:contact_email],
         subject: subject)
  end

  ##
  # Sends an email to the depositor, creators, and curators for use when a dataset is deposited.
  # @param dataset_key [String] the key of the dataset
  def confirm_deposit(dataset_key)
    @dataset = Dataset.find_by(key: dataset_key)
    if @dataset
      subject_base = "Illinois Data Bank] Dataset deposited (#{@dataset.identifier})"
      subject = prepend_system_code(subject_base)
      to_array = []
      to_array << @dataset.depositor_email
      @dataset.creators.each do |creator|
        to_array << creator.email
      end
      to_array << IDB_CONFIG[:admin][:contact_email]
      to_array << IDB_CONFIG[:admin][:temp_contact_email]
      mail(to: to_array, subject: subject)
    else
      Rails.logger.warn "Confirmation email not sent: #{dataset_key}."
    end
  end

  ##
  # Sends an email to the curators for use when a dataset is updated.
  def confirm_deposit_update(dataset_key)
    @dataset = Dataset.find_by(key: dataset_key)
    if @dataset
      subject_base = "Illinois Data Bank] Dataset updated (#{@dataset.identifier})"
      subject = prepend_system_code(subject_base)
      mail(to: [IDB_CONFIG[:admin][:contact_email], IDB_CONFIG[:admin][:temp_contact_email]], subject: subject)
    else
      Rails.logger.warn "Update confirmation email not sent: #{dataset_key}."
    end
  end

  ##
  # Sends an email to the curators for use when a user requests help.
  # @param params [Hash] the parameters of the help request
  # params hash has two keys:
  #  "help-email" [String] the email of the user requesting help
  #  "help-topic" [String] the topic of the help request
  def contact_help(params)
    subject = prepend_system_code("Illinois Data Bank] Help Request")
    unless valid_email?(address: params["help-email"])
      Rails.logger.warn("invalid email request from: #{params["help-email"]}")
      return
    end
    @params = params
    if @params["help-topic"] == "Dataset Consultation"
      subject_base = "Illinois Data Bank] Dataset Consultation Request"
      subject = prepend_system_code(subject_base)
    end
    mail(from:    IDB_CONFIG[:admin][:contact_email],
         to:      [IDB_CONFIG[:admin][:contact_email],
                   IDB_CONFIG[:admin][:temp_contact_email],
                   @params["help-email"]],
         subject: subject)
  end

  ##
  # Checks if an email address is valid in terms of format.
  # @param address [String] the email address to check
  # @return [Boolean] true if the email address is valid, false otherwise
  def valid_email?(address:)
    pattern = URI::MailTo::EMAIL_REGEXP
    pattern.match?(address)
  end

  ##
  # Sends an email to the depositor for use when a dataset is incomplete for 1 month.
  # @param dataset_key [String] the key of the dataset
  def dataset_incomplete_1m(dataset_key)
    subject_base = "Illinois Data Bank] Incomplete dataset deposit"
    subject = prepend_system_code(subject_base)
    @dataset = Dataset.find_by(key: dataset_key)
    if @dataset
      mail(to:      dataset.depositor_email,
           cc:      [IDB_CONFIG[:admin][:contact_email], IDB_CONFIG[:admin][:temp_contact_email]],
           subject: subject)
    else
      Rails.logger.warn "Dataset incomplete 1m email not sent: #{dataset_key}."
    end
  end

  ##
  # Sends an email to the depositor for use when the embargo is approaching in 1 month.
  # @param dataset_key [String] the key of the dataset
  def embargo_approaching_1m(dataset_key)
    subject_base = "Illinois Data Bank] Dataset release date approaching"
    subject = prepend_system_code(subject_base)
    @dataset = Dataset.find_by(key: dataset_key)
    if @dataset
      mail(to:      @dataset.depositor_email,
           cc:      [IDB_CONFIG[:admin][:contact_email], IDB_CONFIG[:admin][:temp_contact_email]],
           subject: subject)
    else
      Rails.logger.warn "Embargo 1m email not sent: #{dataset_key}."
    end
  end

  ##
  # Sends an email to the depositor for use when the embargo is approaching in 1 week.
  # @param dataset_key [String] the key of the dataset
  def embargo_approaching_1w(dataset_key)
    subject_base = "Illinois Data Bank] Dataset release date approaching"
    subject = prepend_system_code(subject_base)
    @dataset = Dataset.find_by(key: dataset_key)
    if @dataset
      mail(to:      @dataset.depositor_email,
           cc:      [IDB_CONFIG[:admin][:contact_email], IDB_CONFIG[:admin][:temp_contact_email]],
           subject: subject)
    else
      Rails.logger.warn "Embargo 1w email not sent: #{dataset_key}."
    end
  end

  ##
  # Sends an email to the tech team for use when an error occurs.
  # @param error_text [String] the error message
  def error(error_text)
    @error_text = error_text
    subject = prepend_system_code("Illinois Data Bank] System Error")
    mail(to: IDB_CONFIG[:admin][:tech_mail_list].to_s, subject: subject)
  end

  ##
  # Sends an email to the tech team for use when a confirmation email is not sent.
  # @param dataset_key [String] the key of the dataset
  # @param err [String] the error message
  def confirmation_not_sent(dataset_key, err)
    subject_base = "Illinois Data Bank] Dataset confirmation email not sent"
    subject = prepend_system_code(subject_base)
    @err = err
    @dataset = Dataset.find_by(key: dataset_key)
    if @dataset
      mail(to: [IDB_CONFIG[:admin][:contact_email], IDB_CONFIG[:admin][:temp_contact_email]], subject: subject)
    else
      Rails.logger.warn "Confirmation email not sent email not sent \
because dataset not found for key: #{dataset_key}."
    end
  end

  ##
  # Sends an email to the user for use when an account is activated.
  # @param identity [Identity] the identity of the user
  def account_activation(identity)
    @identity = identity
    mail(to: @identity.email, subject: "Illinois Data Bank account activation")
  end

  ##
  # Sends an email to the user for use when a password is reset.
  # @param identity [Identity] the identity of the user
  def password_reset(identity)
    @identity = identity
    mail(to: @identity.email, subject: "Illinois Data Bank password reset")
  end

  ##
  # Sends an email to the admin with a report of the related materials links.
  # The report includes the status of the links.
  def link_report
    subject_base = "Illinois Data Bank] Related Materials Links Status Report"
    subject = prepend_system_code(subject_base)
    @report = RelatedMaterial.link_report
    mail(to: IDB_CONFIG[:admin][:materials_report_list].to_s, subject: subject)
  end

  def curator_report(report)
    subject_base = "Illinois Data Bank] #{report.report_type} Report"
    subject = prepend_system_code(subject_base)
    @curator_report = report
    mail(to: report.requestor_email, subject: subject)
  end

  ##
  # Sends an email to the admin when a file change is made in a dataset under pre
  # publication review.
  # @param datafile_web_id [String] the web ID of the datafile that was changed
  def prepub_filechange(datafile_web_id, change_type)
    @datafile = Datafile.find_by(web_id: datafile_web_id)
    @change_type = change_type
    @dataset = @datafile.dataset
    subject_base = "Illinois Data Bank] File change in dataset under pre-publication review"
    subject = prepend_system_code(subject_base)
    mail(to: IDB_CONFIG[:admin][:contact_email], subject: subject)
  end

  ##
  # Prepends a system code to the subject of an email.
  # @param subject [String] the subject of the email
  # @return [String] the subject with the system code prepended
  def prepend_system_code(subject)
    if IDB_CONFIG[:root_url_text].include?("demo")
      "[DEMO: " + subject
    elsif IDB_CONFIG[:root_url_text].include?("localhost")
      "[LOCAL: " + subject
    else
      "[" + subject
    end
  end
end
