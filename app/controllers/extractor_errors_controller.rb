class ExtractorErrorsController < ApplicationController
  before_action :set_extractor_error, only: %i[ show edit update destroy ]

  # Responds to `GET /extractor_errors or /extractor_errors.json`
  def index
    @extractor_errors = ExtractorError.all
  end

  # Responds to `GET /extractor_errors/1 or /extractor_errors/1.json`
  def show; end

  # Responds to `GET /extractor_errors/new`
  def new
    @extractor_error = ExtractorError.new
  end

  # Responds to `GET /extractor_errors/1/edit`
  def edit; end

  # Responds to `POST /extractor_errors or /extractor_errors.json`
  def create
    @extractor_error = ExtractorError.new(extractor_error_params)

    respond_to do |format|
      if @extractor_error.save
        format.html { redirect_to @extractor_error, notice: "Extractor error was successfully created." }
        format.json { render :show, status: :created, location: @extractor_error }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @extractor_error.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `PATCH/PUT /extractor_errors/1 or /extractor_errors/1.json`
  def update
    respond_to do |format|
      if @extractor_error.update(extractor_error_params)
        format.html { redirect_to @extractor_error, notice: "Extractor error was successfully updated." }
        format.json { render :show, status: :ok, location: @extractor_error }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @extractor_error.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `DELETE /extractor_errors/1 or /extractor_errors/1.json`
  def destroy
    @extractor_error.destroy
    respond_to do |format|
      format.html { redirect_to extractor_errors_url, notice: "Extractor error was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_extractor_error
    @extractor_error = ExtractorError.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def extractor_error_params
    params.require(:extractor_error).permit(:extractor_response_id, :error_type, :report)
  end
end
