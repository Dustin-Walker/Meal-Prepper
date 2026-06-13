require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @recipe = recipes(:one)
  end

  test "should get index" do
    get recipes_url
    assert_response :success
  end

  test "should get new" do
    get new_recipe_url
    assert_response :success
  end

  test "should create recipe" do
    assert_difference("Recipe.count") do
      post recipes_url, params: { recipe: { cook_time_minutes: @recipe.cook_time_minutes, description: @recipe.description, generation_request_id: @recipe.generation_request_id, instructions: @recipe.instructions, is_published: @recipe.is_published, prep_time_minutes: @recipe.prep_time_minutes, servings: @recipe.servings, title: @recipe.title, user_id: @recipe.user_id } }
    end

    assert_redirected_to recipe_url(Recipe.last)
  end

  test "should show recipe" do
    get recipe_url(@recipe)
    assert_response :success
  end

  test "should get edit" do
    get edit_recipe_url(@recipe)
    assert_response :success
  end

  test "should update recipe" do
    patch recipe_url(@recipe), params: { recipe: { cook_time_minutes: @recipe.cook_time_minutes, description: @recipe.description, generation_request_id: @recipe.generation_request_id, instructions: @recipe.instructions, is_published: @recipe.is_published, prep_time_minutes: @recipe.prep_time_minutes, servings: @recipe.servings, title: @recipe.title, user_id: @recipe.user_id } }
    assert_redirected_to recipe_url(@recipe)
  end

  test "should destroy recipe" do
    assert_difference("Recipe.count", -1) do
      delete recipe_url(@recipe)
    end

    assert_redirected_to recipes_url
  end
end
