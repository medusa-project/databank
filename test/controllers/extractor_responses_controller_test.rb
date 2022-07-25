require "test_helper"

class ExtractorResponsesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @extractor_response = extractor_responses(:one)
  end

  test "should get index" do
    get extractor_responses_url
    assert_response :success
  end

  test "should get new" do
    get new_extractor_response_url
    assert_response :success
  end

  test "should create extractor_response" do
    assert_difference('ExtractorResponse.count') do
      post extractor_responses_url, params: { extractor_response: { extractor_task_id: @extractor_response.extractor_task_id, peek_text: @extractor_response.peek_text, peek_type: @extractor_response.peek_type, status: @extractor_response.status, web_id: @extractor_response.web_id } }
    end

    assert_redirected_to extractor_response_url(ExtractorResponse.last)
  end

  test "should show extractor_response" do
    get extractor_response_url(@extractor_response)
    assert_response :success
  end

  test "should get edit" do
    get edit_extractor_response_url(@extractor_response)
    assert_response :success
  end

  test "should update extractor_response" do
    patch extractor_response_url(@extractor_response), params: { extractor_response: { extractor_task_id: @extractor_response.extractor_task_id, peek_text: @extractor_response.peek_text, peek_type: @extractor_response.peek_type, status: @extractor_response.status, web_id: @extractor_response.web_id } }
    assert_redirected_to extractor_response_url(@extractor_response)
  end

  test "should destroy extractor_response" do
    assert_difference('ExtractorResponse.count', -1) do
      delete extractor_response_url(@extractor_response)
    end

    assert_redirected_to extractor_responses_url
  end
end
