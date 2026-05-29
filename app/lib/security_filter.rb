module SecurityFilter
  # Named patterns for common injection attempts on short user-supplied text
  # (name <= 50 chars, content <= 20 chars). Kept tight so legitimate Chinese
  # memorial text rarely triggers — event_handler in particular requires HTML
  # tag context, so plain words like "one=" do not match.
  PATTERNS = {
    script_tag:        /<\s*script\b/i,
    iframe_tag:        /<\s*iframe\b/i,
    svg_tag:           /<\s*svg\b/i,
    event_handler:     /<\s*\w+[^>]*\bon\w+\s*=/i,
    js_uri:            /javascript\s*:/i,
    sql_union_select:  /\bunion\s+(all\s+)?select\b/i,
    sql_quote_comment: /'\s*;?\s*(--|#|\/\*)/,
    sql_or_eq:         /\b(or|and)\b\s+["']?\d+["']?\s*=\s*["']?\d+["']?/i,
    path_traversal:    /\.\.[\\\/]/
  }.freeze

  module_function

  # Returns the symbol of the first pattern the text matches, or nil if clean.
  def attack_signature(text)
    return nil if text.nil? || text.empty?
    PATTERNS.each { |name, regex| return name if text.match?(regex) }
    nil
  end
end
