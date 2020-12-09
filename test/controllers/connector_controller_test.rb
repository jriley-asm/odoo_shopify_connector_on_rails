require 'test_helper'

class ConnectorControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get connector_index_url
    assert_response :success
  end

end
