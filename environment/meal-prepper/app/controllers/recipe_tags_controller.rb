class RecipeTagsController < ApplicationController
  before_action :set_recipe_tag, only: %i[ show edit update destroy ]

  # GET /recipe_tags or /recipe_tags.json
  def index
    @recipe_tags = RecipeTag.all
  end

  # GET /recipe_tags/1 or /recipe_tags/1.json
  def show
  end

  # GET /recipe_tags/new
  def new
    @recipe_tag = RecipeTag.new
  end

  # GET /recipe_tags/1/edit
  def edit
  end

  # POST /recipe_tags or /recipe_tags.json
  def create
    @recipe_tag = RecipeTag.new(recipe_tag_params)

    respond_to do |format|
      if @recipe_tag.save
        format.html { redirect_to @recipe_tag, notice: "Recipe tag was successfully created." }
        format.json { render :show, status: :created, location: @recipe_tag }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @recipe_tag.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /recipe_tags/1 or /recipe_tags/1.json
  def update
    respond_to do |format|
      if @recipe_tag.update(recipe_tag_params)
        format.html { redirect_to @recipe_tag, notice: "Recipe tag was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @recipe_tag }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @recipe_tag.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /recipe_tags/1 or /recipe_tags/1.json
  def destroy
    @recipe_tag.destroy!

    respond_to do |format|
      format.html { redirect_to recipe_tags_path, notice: "Recipe tag was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_recipe_tag
      @recipe_tag = RecipeTag.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def recipe_tag_params
      params.expect(recipe_tag: [ :recipe_id, :tag_id ])
    end
end
