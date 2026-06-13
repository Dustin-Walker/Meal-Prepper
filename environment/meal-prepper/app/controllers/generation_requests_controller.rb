class GenerationRequestsController < ApplicationController
  before_action :set_generation_request, only: %i[ show edit update destroy ]

  # GET /generation_requests or /generation_requests.json
  def index
    @generation_requests = GenerationRequest.all
  end

  # GET /generation_requests/1 or /generation_requests/1.json
  def show
  end

  # GET /generation_requests/new
  def new
    @generation_request = GenerationRequest.new
  end

  # GET /generation_requests/1/edit
  def edit
  end

  # POST /generation_requests or /generation_requests.json
  def create
    @generation_request = GenerationRequest.new(generation_request_params)

    respond_to do |format|
      if @generation_request.save
        format.html { redirect_to @generation_request, notice: "Generation request was successfully created." }
        format.json { render :show, status: :created, location: @generation_request }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @generation_request.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /generation_requests/1 or /generation_requests/1.json
  def update
    respond_to do |format|
      if @generation_request.update(generation_request_params)
        format.html { redirect_to @generation_request, notice: "Generation request was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @generation_request }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @generation_request.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /generation_requests/1 or /generation_requests/1.json
  def destroy
    @generation_request.destroy!

    respond_to do |format|
      format.html { redirect_to generation_requests_path, notice: "Generation request was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_generation_request
      @generation_request = GenerationRequest.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def generation_request_params
      params.expect(generation_request: [ :user_id, :prompt, :raw_response, :model_used, :status ])
    end
end
