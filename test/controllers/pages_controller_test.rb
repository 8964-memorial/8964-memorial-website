require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_path
    assert_response :success
    assert_select "h1", "紀念六四 - 1989年六四天安門事件追思"
  end

  test "should display messages on index" do
    get root_path
    assert_response :success
    assert_select ".light-box", count: Message.count
  end

  test "should get say form" do
    with_commenting_enabled do
      get say_path
      assert_response :success
      assert_select "form"
      assert_select "input[name='message[name]']"
      assert_select "textarea[name='message[content]']"
    end
  end

  test "should create message with valid params" do
    with_commenting_enabled do
      assert_difference('Message.count') do
        post say_path, params: { message: { name: "測試用戶", content: "測試留言" } }
      end
      assert_redirected_to root_path
    end
  end

  test "should not create message with invalid params" do
    with_commenting_enabled do
      assert_no_difference('Message.count') do
        post say_path, params: { message: { name: "", content: "" } }
      end
      assert_response :success
      assert_select "textarea[name='message[content]']"
    end
  end

  test "should not create message with content too long" do
    with_commenting_enabled do
      assert_no_difference('Message.count') do
        post say_path, params: { message: { name: "測試用戶", content: "這是一個超過二十個字的測試內容用來驗證長度限制功能" } }
      end
      assert_response :success
      assert_select "textarea[name='message[content]']"
    end
  end

  test "should have Facebook event banner link" do
    get root_path
    assert_select "a.banner[href*='facebook.com']"
    assert_select "a.banner img[src*='64event']"
  end

  test "should have memorial button and say link when commenting enabled" do
    with_commenting_enabled do
      get root_path
      assert_select "button.btn", "開始紀念"
      assert_select "a.btn[href='#{say_path}']", "留言"
    end
  end

  test "should not show say link when commenting disabled" do
    with_commenting_disabled do
      get root_path
      assert_select "button.btn", "開始紀念"
      assert_select "a.btn[href='#{say_path}']", count: 0
    end
  end

  test "should redirect to root when accessing say page with commenting disabled" do
    with_commenting_disabled do
      get say_path
      assert_redirected_to root_path
      assert_equal '留言功能目前已關閉', flash[:alert]
    end
  end

  test "should not create message when commenting disabled" do
    with_commenting_disabled do
      assert_no_difference('Message.count') do
        post say_path, params: { message: { name: "測試用戶", content: "測試留言" } }
      end
      assert_redirected_to root_path
      assert_equal '留言功能目前已關閉', flash[:alert]
    end
  end

  private

  def with_commenting_enabled
    original_config = Rails.application.config.memorial
    Rails.application.config.memorial = { features: { commenting_enabled: true } }
    yield
  ensure
    Rails.application.config.memorial = original_config
  end

  def with_commenting_disabled
    original_config = Rails.application.config.memorial
    Rails.application.config.memorial = { features: { commenting_enabled: false } }
    yield
  ensure
    Rails.application.config.memorial = original_config
  end
end
