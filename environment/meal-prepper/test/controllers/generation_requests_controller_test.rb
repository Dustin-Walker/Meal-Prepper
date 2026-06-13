require "test_helper"

class GenerationRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @generation_request = generation_requests(:one)
  end

  test "should get index" do
    get generation_requests_url
    assert_response :success
  end

  test "should get new" do
    get new_generation_request_url
    assert_response :success
  end

  test "should create generation_request" do
    assert_difference("GenerationRequest.count") do
      post generation_requests_url, params: { generation_request: { model_used: @generation_request.model_used, prompt: @generation_request.prompt, raw_response: @generation_request.raw_response, status: @generation_request.status, user_id: @generation_request.user_id } }
    end

    assert_redirected_to generation_request_url(GenerationRequest.last)
  end

  test "should show generation_request" do
    get generation_request_url(@generation_request)
    assert_response :success
  end

  test "should get edit" do
    get edit_generation_request_url(@generation_request)
    assert_response :success
  end

  test "should update generation_request" do
    patch generation_request_url(@generation_request), params: { generation_request: { model_used: @generation_request.model_used, prompt: @generation_request.prompt, raw_response: @generation_request.raw_response, status: @generation_request.status, user_id: @generation_request.user_id } }
    assert_redirected_to generation_request_url(@generation_request)
  end

  test "should destroy generation_request" do
    assert_difference("GenerationRequest.count", -1) do
      delete generation_request_url(@generation_request)
    end

    assert_redirected_to generation_requests_url
  end
end
