namespace :memorial do
  desc "Export messages to JSON or CSV format"
  task :export, [:format] => :environment do |task, args|
    format = args[:format] || 'json'
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    
    unless %w[json csv].include?(format.downcase)
      puts "Error: Format must be 'json' or 'csv'"
      exit 1
    end
    
    messages = Message.all
    
    if messages.empty?
      puts "No messages found to export."
      exit 0
    end
    
    # Use backup directory as default
    backup_dir = File.join(Rails.root, 'backup')
    
    case format.downcase
    when 'json'
      export_to_json(messages, timestamp, backup_dir)
    when 'csv'
      export_to_csv(messages, timestamp, backup_dir)
    end
  end

  desc "Generate static HTML version with all assets"
  task :static => :environment do
    puts "🌟 Generating static HTML version of memorial site..."
    
    # Switch to production environment to use production database
    original_env = Rails.env
    # Rails.env = 'production'
    
    # Reload ActiveRecord to use production database configuration
    if ActiveRecord::Base.respond_to?(:clear_all_connections!)
      ActiveRecord::Base.clear_all_connections!
    else
      ActiveRecord::Base.connection_handler.clear_all_connections!
    end
    ActiveRecord::Base.establish_connection
    
    begin
      # Create static output directory
      static_dir = File.join(Rails.root, 'static_output')
      static_zip_dir = File.join(Rails.root, 'static_zip')
      FileUtils.rm_rf(static_dir) if Dir.exist?(static_dir)
      FileUtils.mkdir_p(static_dir)
      FileUtils.mkdir_p(static_zip_dir) if not Dir.exist?(static_zip_dir)
      
      # Generate static HTML
      generate_static_html(static_dir)
      
      # Copy assets
      copy_assets(static_dir)
      
      # Create zip file with date suffix
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      zip_filename = "memorial_static_#{timestamp}.zip"
      zip_filepath = File.join(static_zip_dir, zip_filename)
      
      create_zip_file(static_dir, zip_filepath)
      
      puts "✅ Static site generated successfully in: #{static_dir}"
      puts "📦 Static site compressed to: #{zip_filepath}"
      puts "📁 You can now host the contents of this directory on any static hosting service."
      puts "🗄️  Using production database: #{ActiveRecord::Base.connection_db_config.database}"
    ensure
      # Restore original environment
      Rails.env = original_env
      if ActiveRecord::Base.respond_to?(:clear_all_connections!)
        ActiveRecord::Base.clear_all_connections!
      else
        ActiveRecord::Base.connection_handler.clear_all_connections!
      end
      ActiveRecord::Base.establish_connection
    end
  end

  desc "Clear all messages with confirmation"
  task :clear => :environment do
    message_count = Message.count
    
    if message_count == 0
      puts "No messages to clear."
      exit 0
    end
    
    puts "⚠️  WARNING: You are about to delete #{message_count} messages!"
    puts ""
    puts "📥 BACKUP OPTIONS:"
    puts "Before deleting, would you like to create a backup?"
    puts ""
    print "Create automatic backup? (Y/n): "
    
    backup_choice = $stdin.gets&.chomp&.downcase || ''
    
    # Default to 'yes' if user just presses enter or says yes
    if backup_choice.empty? || %w[y yes].include?(backup_choice)
      puts ""
      puts "Creating backup..."
      
      # Create both JSON and CSV backups
      messages = Message.all
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      
      begin
        backup_dir = File.join(Rails.root, 'backup')
        export_to_json(messages, timestamp, backup_dir)
        export_to_csv(messages, timestamp, backup_dir)
        puts "✅ Backup completed!"
        puts ""
      rescue => e
        puts "❌ Backup failed: #{e.message}"
        puts "Please manually backup your data before proceeding."
        puts ""
        puts "Manual backup commands:"
        puts "  rails memorial:export[json]"
        puts "  rails memorial:export[csv]"
        puts ""
        print "Continue without backup? (y/N): "
        
        continue_without_backup = $stdin.gets&.chomp&.downcase || ''
        unless %w[y yes].include?(continue_without_backup)
          puts "Clear operation cancelled."
          exit 0
        end
      end
    elsif %w[n no].include?(backup_choice)
      puts ""
      puts "Skipping backup as requested."
      puts ""
      puts "Manual backup commands (if needed):"
      puts "  rails memorial:export[json]"
      puts "  rails memorial:export[csv]"
      puts ""
    else
      puts "Invalid choice. Please backup manually and run this command again."
      puts ""
      puts "Manual backup commands:"
      puts "  rails memorial:export[json]"
      puts "  rails memorial:export[csv]"
      exit 0
    end
    
    print "Are you sure you want to delete ALL #{message_count} messages? This cannot be undone! (y/N): "
    
    final_confirm = $stdin.gets&.chomp&.downcase || ''
    unless %w[y yes].include?(final_confirm)
      puts "Clear operation cancelled."
      exit 0
    end
    
    Message.delete_all
    ActiveRecord::Base.connection.execute("ALTER TABLE messages AUTO_INCREMENT = 1") if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
    
    puts "✅ All messages have been cleared successfully."
  end

  private

  def create_zip_file(source_dir, zip_filepath)
    require 'zip'
    
    puts "📦 Creating zip file: #{File.basename(zip_filepath)}"
    
    Zip::File.open(zip_filepath, Zip::File::CREATE) do |zipfile|
      Dir.glob(File.join(source_dir, '**', '*')).each do |file|
        next if File.directory?(file)
        
        # Get relative path from source directory
        relative_path = file.sub("#{source_dir}/", '')
        zipfile.add(relative_path, file)
      end
    end
    
    file_size = File.size(zip_filepath)
    file_size_mb = (file_size / 1024.0 / 1024.0).round(2)
    puts "✅ Zip file created successfully (#{file_size_mb} MB)"
  rescue LoadError
    puts "❌ Error: 'zip' gem not found. Please add 'gem \"rubyzip\"' to your Gemfile and run 'bundle install'"
    puts "   Skipping zip file creation."
  rescue => e
    puts "❌ Error creating zip file: #{e.message}"
    puts "   Static files are still available in: #{source_dir}"
  end

  def generate_static_html(static_dir)
    # Get all messages ordered by name for consistent backend ordering
    # but will be shuffled by JavaScript on frontend
    messages = Message.order(:name)
    
    # Create the static HTML content
    html_content = generate_html_template(messages)
    
    # Write index.html
    File.write(File.join(static_dir, 'index.html'), html_content)
    puts "✅ Generated index.html with #{messages.count} messages"
  end

  def copy_assets(static_dir)
    # Create assets directories
    assets_dir = File.join(static_dir, 'assets')
    FileUtils.mkdir_p(File.join(assets_dir, 'images'))
    FileUtils.mkdir_p(File.join(assets_dir, 'stylesheets'))
    
    # Copy images
    images_source = File.join(Rails.root, 'app', 'assets', 'images')
    if Dir.exist?(images_source)
      FileUtils.cp_r(Dir.glob(File.join(images_source, '*')), File.join(assets_dir, 'images'))
      puts "✅ Copied image assets"
    end
    
    # Copy public assets
    public_source = File.join(Rails.root, 'public')
    if Dir.exist?(public_source)
      Dir.glob(File.join(public_source, '*')).each do |item|
        next if File.basename(item) == 'assets' # Skip compiled assets for now
        if File.directory?(item)
          FileUtils.cp_r(item, static_dir)
        else
          FileUtils.cp(item, static_dir)
        end
      end
      puts "✅ Copied public assets"
    end
    
    # Generate compiled CSS content
    generate_compiled_css(assets_dir)
  end

  def generate_compiled_css(assets_dir)
    # Read the main SCSS file and basic CSS
    scss_content = ""
    
    scss_file = File.join(Rails.root, 'app', 'assets', 'stylesheets', 'styles.css.scss')
    if File.exist?(scss_file)
      scss_content = File.read(scss_file)
      
      # Convert Rails image-url() helpers to relative paths for static site
      scss_content = scss_content.gsub(/image-url\(["']([^"']+)["']\)/) do |match|
        image_name = $1
        "url(/assets/images/#{image_name})"
      end
    end
    
    # Write as CSS (basic conversion - for full SCSS compilation would need Sass gem)
    css_file = File.join(assets_dir, 'stylesheets', 'application.css')
    File.write(css_file, scss_content)
    puts "✅ Generated CSS file with converted image paths"
  end

  def generate_html_template(messages)
    # Generate message data as JSON for JavaScript shuffling
    messages_json = messages.map do |message|
      {
        name: message.name,
        content: message.content
      }
    end.to_json

    # Escape <, >, & to their JSON unicode escapes so message content can never
    # break out of the inline <script> block in the generated static HTML
    # (defense in depth on top of the Message model's input sanitization).
    js_safe = { "<" => "\\u003c", ">" => "\\u003e", "&" => "\\u0026" }
    messages_json = messages_json.gsub(/[<>&]/, js_safe)
    
    <<~HTML
      <!DOCTYPE html>
      <html lang="zh-Hant-TW">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <link rel="stylesheet" href="assets/stylesheets/application.css" media="all">
          <title>紀念六四：線上悼念 - 1989年六四天安門事件紀念網站</title>
          <link rel="icon" type="image/png" href="assets/images/favicon.png">
          <meta name="description" content="1989年六四天安門事件線上紀念網站，歡迎大家在此點起一支蠟燭，留下追思訊息，共同悼念六四事件。">
          <meta name="keywords" content="六四,天安門,1989,紀念,悼念,民主,人權,追思,八九民運">
          <meta name="author" content="雨蒼">
          <meta name="robots" content="index, follow">
          
          <!-- Open Graph / Facebook -->
          <meta property="og:title" content="紀念六四：線上悼念 - 1989年六四天安門事件紀念網站">
          <meta property="og:type" content="website">
          <meta property="og:url" content="https://vigil.8964.memorial">
          <meta property="og:image" content="https://vigil.8964.memorial/static/og-image.png">
          <meta property="og:description" content="1989年六四天安門事件線上紀念網站，歡迎大家在此點起一支蠟燭，留下追思訊息，共同悼念六四事件。">
          <meta property="og:site_name" content="紀念六四">
          
          <!-- Twitter Card -->
          <meta name="twitter:card" content="summary_large_image">
          <meta name="twitter:title" content="紀念六四：線上悼念 - 1989年六四天安門事件紀念網站">
          <meta name="twitter:description" content="1989年六四天安門事件線上紀念網站，歡迎大家在此點起一支蠟燭，留下追思訊息，共同悼念六四事件。">
          <meta name="twitter:image" content="https://vigil.8964.memorial/static/og-image.png">
          
          <!-- Canonical URL -->
          <link rel="canonical" href="https://vigil.8964.memorial">
          
          <!-- Structured Data -->
          <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@type": "WebSite",
            "name": "紀念六四：線上悼念",
            "description": "1989年六四天安門事件線上紀念網站，歡迎大家在此點起一支蠟燭，留下追思訊息，共同悼念六四事件。",
            "url": "https://vigil.8964.memorial",
            "publisher": {
              "@type": "Person",
              "name": "雨蒼"
            }
          }
          </script>
        </head>
        <body>
          <div class="all-wrap">
            <header>
              <h1>紀念六四 - 1989年六四天安門事件追思</h1>
            </header>
            <main>
              <section class="light-group" aria-label="紀念訊息區">
                <div id="messages-container">
                  <!-- Messages will be populated by JavaScript -->
                </div>
              </section>
            </main>
            <footer>
              <a href="https://www.facebook.com/events/1089019929948553/" class="banner" target="_blank">
                <img src="assets/images/64event.jpg" alt="六四事件紀念活動">
              </a>
              <p>本網站感謝以下組織、個人之貢獻：華人民主書院、Ginger、Iris、Joy Hsu、蕭新晟、雨蒼。</p>
            </footer>
          </div>

          <script>
            // Messages data (ordered by name in backend, will be shuffled here)
            const messages = #{messages_json};
            
            // Shuffle function
            function shuffleArray(array) {
              const shuffled = [...array];
              for (let i = shuffled.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
              }
              return shuffled;
            }
            
            // Render messages
            function renderMessages() {
              const container = document.getElementById('messages-container');
              const shuffledMessages = shuffleArray(messages);
              
              container.innerHTML = shuffledMessages.map(message => `
                <article class="light-box" itemscope itemtype="https://schema.org/Comment">
                  <h2 itemprop="author">${escapeHtml(message.name)}</h2>
                  <div class="txt" itemprop="text">
                    ${escapeHtml(message.content)}
                  </div>
                </article>
              `).join('');
            }
            
            // HTML escape function
            function escapeHtml(text) {
              const div = document.createElement('div');
              div.textContent = text;
              return div.innerHTML;
            }
            
            // Initialize on page load with random shuffle
            document.addEventListener('DOMContentLoaded', renderMessages);
          </script>
        </body>
      </html>
    HTML
  end

  def export_to_json(messages, timestamp, backup_dir = nil)
    backup_dir ||= Rails.root
    filename = "memorial_messages_#{timestamp}.json"
    filepath = File.join(backup_dir, filename)
    
    # Create backup directory if it doesn't exist
    FileUtils.mkdir_p(backup_dir) if backup_dir != Rails.root
    
    data = messages.map do |message|
      {
        id: message.id,
        name: message.name,
        content: message.content,
        created_at: message.created_at.iso8601,
        updated_at: message.updated_at.iso8601
      }
    end
    
    File.write(filepath, JSON.pretty_generate(data))
    puts "✅ Exported #{messages.count} messages to #{filepath}"
  end

  def export_to_csv(messages, timestamp, backup_dir = nil)
    require 'csv'
    backup_dir ||= Rails.root
    filename = "memorial_messages_#{timestamp}.csv"
    filepath = File.join(backup_dir, filename)
    
    # Create backup directory if it doesn't exist
    FileUtils.mkdir_p(backup_dir) if backup_dir != Rails.root
    
    CSV.open(filepath, 'w', headers: true) do |csv|
      csv << ['ID', '姓名', '留言內容', '建立時間', '更新時間']
      
      messages.each do |message|
        csv << [
          message.id,
          message.name,
          message.content,
          message.created_at.strftime('%Y-%m-%d %H:%M:%S'),
          message.updated_at.strftime('%Y-%m-%d %H:%M:%S')
        ]
      end
    end
    
    puts "✅ Exported #{messages.count} messages to #{filepath}"
  end
end