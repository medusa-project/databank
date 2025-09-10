# override controller from gem to handle workers re-trying failed jobs

module ProgressJob
  class ProgressController < ActionController::Base

    def show

      begin

        @delayed_job = Delayed::Job.find(params[:job_id])
        percentage = !@delayed_job.progress_max.zero? ? @delayed_job.progress_current / @delayed_job.progress_max.to_f * 100 : 0
        render json: @delayed_job.attributes.merge!(percentage: percentage).to_json

      rescue ActiveRecord::RecordNotFound => ex

        # This happens three times every time a job completes, because of how the deamons function
        render json: {
                   "id" => Integer(params[:job_id]),
                   "priority" => 0,
                   "attempts" => 0,
                   "handler" => "",
                   "last_error" => "complete",
                   "run_at" => "",
                   "locked_at" => "",
                   "failed_at" => "#{Time.now.utc}",
                   "locked_by" => "",
                   "queue" => nil,
                   "created_at" => "",
                   "updated_at" => "",
                   "progress_stage" => "complete",
                   "progress_current" => 100,
                   "progress_max" => 100,
                   "percentage" => 100
               }
      end
    end

  end
end