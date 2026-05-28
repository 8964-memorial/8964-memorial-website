require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "should be valid with name and content" do
    message = Message.new(name: "測試用戶", content: "測試內容")
    assert message.valid?
  end

  test "should be invalid without name" do
    message = Message.new(content: "測試內容")
    assert_not message.valid?
  end

  test "should be invalid without content" do
    message = Message.new(name: "測試用戶")
    assert_not message.valid?
  end

  test "should be invalid with content longer than 20 characters" do
    message = Message.new(name: "測試用戶", content: "這是一個超過二十個字的測試內容用來驗證長度限制功能")
    assert_not message.valid?
    assert_includes message.errors[:content], "is too long (maximum is 20 characters)"
  end

  test "should be valid with content exactly 20 characters" do
    message = Message.new(name: "測試用戶", content: "剛好二十個字元的測試留言內容正好二十個字")
    assert message.valid?
  end
end
