require "test_helper"

class ExtractorErrorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @extractor_error = extractor_errors(:one)
  end

  test "should get index" do
    get extractor_errors_url
    assert_response :success
  end

  test "should get new" do
    get new_extractor_error_url
    assert_response :success
  end

  test "should create extractor_error" do
    assert_difference('ExtractorError.count') do
      post extractor_errors_url, params: { extractor_error: { error_type: @extractor_error.error_type, extractor_response_id: @extractor_error.extractor_response_id, report: @extractor_error.report } }
    end

    assert_redirected_to extractor_error_url(ExtractorError.last)
  end

  test "should show extractor_error" do
    get extractor_error_url(@extractor_error)
    assert_response :success
  end

  test "should get edit" do
    get edit_extractor_error_url(@extractor_error)
    assert_response :success
  end

  test "should update extractor_error" do
    patch extractor_error_url(@extractor_error), params: { extractor_error: { error_type: @extractor_error.error_type, extractor_response_id: @extractor_error.extractor_response_id, report: @extractor_error.report } }
    assert_redirected_to extractor_error_url(@extractor_error)
  end

  test "should destroy extractor_error" do
    assert_difference('ExtractorError.count', -1) do
      delete extractor_error_url(@extractor_error)
    end

    assert_redirected_to extractor_errors_url
  end
end
