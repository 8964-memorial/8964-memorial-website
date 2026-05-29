require "test_helper"

class SecurityFilterTest < ActiveSupport::TestCase
  test "returns nil for clean Chinese memorial text" do
    assert_nil SecurityFilter.attack_signature("願逝者安息")
    assert_nil SecurityFilter.attack_signature("張三")
    assert_nil SecurityFilter.attack_signature("永遠不會忘記六四")
  end

  test "returns nil for nil or empty input" do
    assert_nil SecurityFilter.attack_signature(nil)
    assert_nil SecurityFilter.attack_signature("")
  end

  test "returns nil for harmless punctuation" do
    # "5 < 6" looks superficially HTML-ish but is plain text, not a tag start.
    assert_nil SecurityFilter.attack_signature("5 < 6")
    # "no one=person" — naive /\bon\w+=/ would false-match; our regex requires
    # an HTML tag context, so plain text passes.
    assert_nil SecurityFilter.attack_signature("no one=person")
  end

  test "detects script tag" do
    assert_equal :script_tag, SecurityFilter.attack_signature("<script>x</script>")
    assert_equal :script_tag, SecurityFilter.attack_signature("< script>")
  end

  test "detects iframe and svg tags" do
    assert_equal :iframe_tag, SecurityFilter.attack_signature("<iframe src=x>")
    assert_equal :svg_tag, SecurityFilter.attack_signature("<svg/onload=x>")
  end

  test "detects event handler inside HTML tag" do
    assert_equal :event_handler, SecurityFilter.attack_signature("<img src=x onerror=alert(1)>")
    assert_equal :event_handler, SecurityFilter.attack_signature("<a onclick=alert(1)>")
  end

  test "detects javascript: URI" do
    assert_equal :js_uri, SecurityFilter.attack_signature("javascript:alert(1)")
  end

  test "detects SQL UNION SELECT" do
    assert_equal :sql_union_select, SecurityFilter.attack_signature("1 UNION SELECT pw FROM users")
    assert_equal :sql_union_select, SecurityFilter.attack_signature("a UNION ALL SELECT 1")
  end

  test "detects classic quote + comment SQL injection" do
    assert_equal :sql_quote_comment, SecurityFilter.attack_signature("admin'--")
    assert_equal :sql_quote_comment, SecurityFilter.attack_signature("x';/*")
  end

  test "detects OR 1=1 boolean injection" do
    assert_equal :sql_or_eq, SecurityFilter.attack_signature("' OR 1=1")
    assert_equal :sql_or_eq, SecurityFilter.attack_signature('" or "1"="1')
  end

  test "detects path traversal" do
    assert_equal :path_traversal, SecurityFilter.attack_signature("../../etc/passwd")
    assert_equal :path_traversal, SecurityFilter.attack_signature("..\\windows\\system32")
  end
end
