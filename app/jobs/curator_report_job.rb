# frozen_string_literal: true

class CuratorReportJob
    def initialize(report)
        # temporary debug logging
        Rails.logger.debug "Initializing CuratorReportJob for report ID #{report.id}, type #{report.report_type}, requested by #{report.requestor_name}"
        @report = report
    end

    def perform
        # Generate the report file and store it in S3
        # temporary debug logging
        Rails.logger.debug "Performing CuratorReportJob for report ID #{@report.id}, type #{@report.report_type}"
        CuratorReport.generate_report(@report)
    end

    # Hooks for delayed_job lifecycle
    def success(job)
        # Email the user when the report is ready
        if Rails.env.test? || Rails.env.development?
            Rails.logger.info("CuratorReportJob succeeded for report ID: #{@report.id}, sending email to user #{@report.requestor_email}")
        else
            DatabankMailer.curation_report(@report).deliver_now
        end
    end

    def error(job, exception)
        # Called when job fails
        Rails.logger.error("CuratorReportJob failed: #{exception.message}")
    end

    def failure(job)
        # Called when job permanently fails after all retries
        Rails.logger.error("CuratorReportJob permanently failed after all retries")
    end
end