require 'csv'
require 'tempfile'

class ReviewRequestsController < ApplicationController

  load_and_authorize_resource

  before_action :set_review_request, only: [:show, :edit, :update, :destroy]

  # GET /review_requests
  # GET /review_requests.json
  def index
    @review_requests = ReviewRequest.all
  end

  # GET /review_requests/1
  # GET /review_requests/1.json
  def show
  end

  # GET /review_requests/new
  def new
    @review_request = ReviewRequest.new
  end

  # GET /review_requests/1/edit
  def edit
  end

  # POST /review_requests
  # POST /review_requests.json
  def create
    @review_request = ReviewRequest.new(review_request_params)

    respond_to do |format|
      if @review_request.save
        format.html { redirect_to "/datasets/#{@review_request.dataset_key}", notice: 'Review request was successfully created.' }
        format.json { render :show, status: :created, location: @review_request }
      else
        format.html { render :new }
        format.json { render json: @review_request.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /review_requests/1
  # PATCH/PUT /review_requests/1.json
  def update
    respond_to do |format|
      if @review_request.update(review_request_params)
        format.html { redirect_to @review_request, notice: 'Review request was successfully updated.' }
        format.json { render :show, status: :ok, location: @review_request }
      else
        format.html { render :edit }
        format.json { render json: @review_request.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /review_requests/1
  # DELETE /review_requests/1.json
  def destroy
    @review_request.destroy
    respond_to do |format|
      format.html { redirect_to review_requests_url, notice: 'Review request was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def report
    requests = ReviewRequest.all
    Tempfile.open("requests_csv") do |t|

      CSV.open(t, 'w') do |report|

        report << ['dataset_url', 'dataset_doi', 'request_date']

        requests.each do |request|

          dataset_doi = 'N/A'

          if request.dataset && request.dataset.identifier && request.dataset.identifier != ''
            dataset_doi = request.dataset.identifier
          end

          report << ["#{IDB_CONFIG[:root_url_text]}/datasets/#{request.dataset_key}",
                     dataset_doi,
                     request.requested_at.iso8601]
        end

      end

      send_file t.path, :type => 'text/csv',
                :disposition => 'attachment',
                :filename => "requests.csv"
    end

  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_review_request
      @review_request = ReviewRequest.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def review_request_params
      params.require(:review_request).permit(:dataset_key, :requested_at)
    end
end
