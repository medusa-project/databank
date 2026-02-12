class CuratorReportsController < ApplicationController

  load_and_authorize_resource
  before_action :set_curator_report, only: %i[ show edit update destroy ]
  
  # POST /curator_reports/file_audit_request
  def request_file_audit
    CuratorReport.initiate_report_generation(Databank::ReportType::FILE_AUDIT, current_user, notes: params[:notes]) 
    respond_to do |format|
      format.html { redirect_to curator_reports_path, notice: "File audit report was successfully requested." }
      format.json { head :no_content }
    end
  end

  # GET /curator_reports or /curator_reports.json
  def index
    @curator_reports = CuratorReport.all
  end

  # GET /curator_reports/1 or /curator_reports/1.json
  def show
  end

  # GET /curator_reports/new
  def new
    @curator_report = CuratorReport.new
  end

  # GET /curator_reports/1/edit
  def edit
  end

  # POST /curator_reports or /curator_reports.json
  def create
    @curator_report = CuratorReport.new(curator_report_params)

    respond_to do |format|
      if @curator_report.save
        format.html { redirect_to @curator_report, notice: "Curator report was successfully created." }
        format.json { render :show, status: :created, location: @curator_report }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @curator_report.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /curator_reports/1 or /curator_reports/1.json
  def update
    respond_to do |format|
      if @curator_report.update(curator_report_params)
        format.html { redirect_to @curator_report, notice: "Curator report was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @curator_report }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @curator_report.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /curator_reports/1 or /curator_reports/1.json
  def destroy
    @curator_report.destroy!

    respond_to do |format|
      format.html { redirect_to curator_reports_path, notice: "Curator report was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_curator_report
      @curator_report = CuratorReport.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def curator_report_params
      params.require(:curator_report).permit(:requestor_name, :requestor_email, :report_type, :storage_root, :storage_key, :notes)
    end
end
