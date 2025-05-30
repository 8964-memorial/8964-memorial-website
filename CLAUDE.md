# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Rails 7.2 memorial website for the June 4th (6/4) incident, running on Ruby 3.2.8. The application is a simple message board where users can leave memorial messages that are displayed randomly on the main page.

## Core Architecture

- **Single Controller Pattern**: Uses `PagesController` with three actions:
  - `index`: Displays all messages in random order
  - `say`: Shows form for creating new messages  
  - `create`: Processes message creation and redirects to home
- **Simple Data Model**: Single `Message` model with `name` and `content` fields, content limited to 20 characters
- **Frontend**: Traditional Rails views with ERB templates, uses Stimulus/Turbo for JavaScript
- **Database**: MySQL with single `messages` table
- **Production**: Configured with Unicorn server

## Development Commands

**Start server:**
```bash
rails server
```

**Run tests:**
```bash
rails test
```

**Run specific test:**
```bash
rails test test/models/message_test.rb
```

**Database operations:**
```bash
rails db:migrate
rails db:seed
```

**Asset compilation:**
```bash
rails assets:precompile
```

**Console:**
```bash
rails console
```

## Key Files

- `app/controllers/pages_controller.rb` - Main application logic
- `app/models/message.rb` - Message validation (20 char limit)
- `app/views/pages/index.html.erb` - Memorial messages display
- `config/routes.rb` - Simple routing: root, /say (GET/POST)
- `db/migrate/20230531164447_create_messages.rb` - Database schema

## Testing Framework

Uses standard Rails testing with:
- Minitest framework
- System tests with Capybara/Selenium
- Test files in `test/` directory following Rails conventions