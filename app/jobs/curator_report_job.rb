# frozen_string_literal: true

class CuratorReportJob
    def initialize(report_type, requesting_user, storage_root)
        @report_type = report_type
        @requesting_user = requesting_user
        @storage_root = storage_root
    end

    def perform
        # Generate the report and store it in S3, then email the user when it's ready.
        requesting_user = @requesting_user.is_a?(User) ? @requesting_user : User.find(@requesting_user)
        report = CuratorReport.create!(report_type: @report_type, requestor_name: requesting_user.name, requestor_email: requesting_user.email)
        report.storage_root = @storage_root
        report.storage_key = report.default_storage_key
        report.save!

        # Generate the report file and store it in S3
        CuratorReport.generate_report(report)
    end

    # Hooks for delayed_job lifecycle
    def success(job)
        # Email the user when the report is ready
        DatabankMailer.curation_report(report.report_type, report.requestor_email).deliver_now
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