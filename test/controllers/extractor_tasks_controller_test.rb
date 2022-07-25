require 'test_helper'

class ExtractorTasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @extractor_task = extractor_tasks(:one)
  end

  test "should get index" do
    get extractor_tasks_url
    assert_response :success
  end

  test "should get new" do
    get new_extractor_task_url
    assert_response :success
  end

  test "should create extractor_task" do
    assert_difference('ExtractorTask.count') do
      post extractor_tasks_url, params: { extractor_task: { response: @extractor_task.response, response_at: @extractor_task.response_at, web_id: @extractor_task.web_id } }
    end

    assert_redirected_to extractor_task_url(ExtractorTask.last)
  end

  test "should show extractor_task" do
    get extractor_task_url(@extractor_task)
    assert_response :success
  end

  test "should get edit" do
    get edit_extractor_task_url(@extractor_task)
    assert_response :success
  end

  test "should update extractor_task" do
    patch extractor_task_url(@extractor_task), params: { extractor_task: { response: @extractor_task.response, response_at: @extractor_task.response_at, web_id: @extractor_task.web_id } }
    assert_redirected_to extractor_task_url(@extractor_task)
  end

  test "should destroy extractor_task" do
    assert_difference('ExtractorTask.count', -1) do
      delete extractor_task_url(@extractor_task)
    end

    assert_redirected_to extractor_tasks_url
  end
end
