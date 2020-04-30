# frozen_string_literal: true

require "open-uri"
require "open_uri_redirections"

# defines and sends email
class DatabankMailer < ActionMailer::Base
  default from: "databank@library.illinois.edu"

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
      mail(to: to_array, cc: "databank@library.illinois.edu", subject: subject)
    else
      Rails.logger.warn "Confirmation email not sent: #{dataset_key}."
    end
  end

  def confirm_deposit_update(dataset_key)
    @dataset = Dataset.find_by(key: dataset_key)
    if @dataset
      subject_base = "Illinois Data Bank] Dataset updated (#{@dataset.identifier})"
      subject = prepend_system_code(subject_base)
      mail(to: "databank@library.illinois.edu", subject: subject)
    else
      Rails.logger.warn "Update confirmation email not sent: #{dataset_key}."
    end
  end

  def contact_help(params)
    subject = prepend_system_code("Illinois Data Bank] Help Request")
    @params = params
    if @params["help-topic"] == "Dataset Consultation"
      subject_base = "Illinois Data Bank] Dataset Consultation Request"
      subject = prepend_system_code(subject_base)
    end
    mail(from:    @params["help-email"],
         to:      ["databank@library.illinois.edu",
                   @params["help-email"]],
         subject: subject)
  end

  def dataset_incomplete_1m(dataset_key)
    subject_base = "Illinois Data Bank] Incomplete dataset deposit"
    subject = prepend_system_code(subject_base)
    @dataset = Dataset.find_by(key: dataset_key)
    if @dataset
      mail(to:      dataset.depositor_email,
           cc:      "databank@library.illinois.edu",
           subject: subject)
    else
      Rails.logger.warn "Dataset incomplete 1m email not sent: #{dataset_key}."
    end
  end

  def embargo_approaching_1m(dataset_key)
    subject_base = "Illinois Data Bank] Dataset release date approaching"
    subject = prepend_system_code(subject_base)
    @dataset = Dataset.find_by(key: dataset_key)
    if @dataset
      mail(to:      @dataset.depositor_email,
           cc:      "databank@library.illinois.edu",
           subject: subject)
    else
      Rails.logger.warn "Embargo 1m email not sent: #{dataset_key}."
    end
  end

  def embargo_approaching_1w(dataset_key)
    subject_base = "Illinois Data Bank] Dataset release date approaching"
    subject = prepend_system_code(subject_base)
    @dataset = Dataset.find_by(key: dataset_key)
    if @dataset
      mail(to:      @dataset.depositor_email,
           cc:      "databank@library.illinois.edu",
           subject: subject)
    else
      Rails.logger.warn "Embargo 1w email not sent: #{dataset_key}."
    end
  end

  def error(error_text)
    @error_text = error_text
    subject = prepend_system_code("Illinois Data Bank] System Error")
    mail(to: IDB_CONFIG[:admin][:tech_mail_list].to_s, subject: subject)
  end

  def ezid_warnings(report)
    @report = report
    subject = prepend_system_code("Illinois Data Bank] EZID Differences Report")
    mail(to: IDB_CONFIG[:admin][:tech_mail_list].to_s, subject: subject)
  end

  def confirmation_not_sent(dataset_key, err)
    subject_base = "Illinois Data Bank] Dataset confirmation email not sent"
    subject = prepend_system_code(subject_base)
    @err = err
    @dataset = Dataset.find_by(key: dataset_key)
    if @dataset
      mail(to: "databank@library.illinois.edu", subject: subject)
    else
      Rails.logger.warn "Confirmation email not sent email not sent \
because dataset not found for key: #{dataset_key}."
    end
  end

  def account_activation(identity)
    @identity = identity
    mail(to: @identity.email, subject: "Illinois Data Bank account activation")
  end

  def password_reset(identity)
    @identity = identity
    mail(to: @identity.email, subject: "Illinois Data Bank password reset")
  end

  def link_report
    subject_base = "Illinois Data Bank] Related Materials Links Status Report"
    subject = prepend_system_code(subject_base)
    @report = RelatedMaterial.link_report
    mail(to: IDB_CONFIG[:admin][:materials_report_list].to_s, subject: subject)
  end

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
