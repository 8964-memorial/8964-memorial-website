# 8964 Memorial Website

紀念六四事件的網站，提供留言點燈功能讓用戶表達追思之意。

## 功能特色

- **首頁展示**：隨機顯示所有紀念留言
- **留言功能**：可開關的留言系統，支援姓名和20字內容留言
- **響應式設計**：支援桌面和行動裝置
- **安全防護**：包含CSRF保護、XSS防護、Content Security Policy等
- **Facebook活動連結**：整合相關紀念活動資訊

## 技術規格

- **Framework**: Ruby on Rails 7.2.2
- **Ruby Version**: 3.2.8
- **Database**: MySQL
- **Web Server**: Unicorn (生產環境)
- **CSS**: SCSS with Sass
- **JavaScript**: Stimulus + Turbo (Hotwire)

## 安裝與開發

### 系統需求

- Ruby 3.2.8
- MySQL 5.5.8+
- Node.js (用於asset pipeline)

### 安裝步驟

1. **複製專案**
   ```bash
   git clone <repository-url>
   cd memorial-app
   ```

2. **安裝依賴**
   ```bash
   bundle install
   ```

3. **設定資料庫**
   ```bash
   # 複製並修改資料庫配置
   cp config/database.yml.default config/database.yml
   # 編輯 config/database.yml 設定您的MySQL連線資訊
   
   # 建立資料庫和執行遷移
   rails db:create
   rails db:migrate
   ```

4. **啟動開發伺服器**
   ```bash
   rails server
   ```

   網站將在 http://localhost:3000 運行

### 開發工具

- **測試**: `rails test`
- **安全掃描**: `bundle exec bundler-audit check`
- **Console**: `rails console`

## 部署

### 配置設定

#### 資料庫配置

複製並編輯資料庫配置檔案：

```bash
cp config/database.yml.default config/database.yml
```

編輯 `config/database.yml` 生產環境設定：

```yaml
production:
  adapter: mysql2
  encoding: utf8mb4
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  database: memorial_production
  username: <%= ENV.fetch("DB_USERNAME") { "memorial" } %>
  password: <%= ENV.fetch("DB_PASSWORD") { "" } %>
  host: <%= ENV.fetch("DB_HOST") { "localhost" } %>
  port: <%= ENV.fetch("DB_PORT") { 3306 } %>
```

#### 環境變數

在生產環境中，可設定以下環境變數：

```bash
# 資料庫連線
DB_USERNAME=your_db_username
DB_PASSWORD=your_db_password
DB_HOST=localhost
DB_PORT=3306

# Rails設定
RAILS_ENV=production
SECRET_KEY_BASE=your_secret_key_base

# 留言功能控制（可選）
MEMORIAL_COMMENTING_ENABLED=true  # true/false

# 靜態檔案服務（如使用Rails服務靜態檔案）
RAILS_SERVE_STATIC_FILES=true

# 日誌輸出到STDOUT（容器化部署）
RAILS_LOG_TO_STDOUT=true
```

#### 留言功能配置

編輯 `config/memorial.yml` 控制留言功能：

```yaml
production:
  features:
    commenting_enabled: true  # 設為false關閉留言功能
```

### Docker部署

創建 `Dockerfile`:

```dockerfile
FROM ruby:3.2.8

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install --deployment --without development test

COPY . .

RUN rails assets:precompile

EXPOSE 3000

CMD ["bundle", "exec", "unicorn", "-c", "unicorn.conf.rb"]
```

### 傳統部署

1. **在伺服器上準備環境**
   ```bash
   # 安裝Ruby 3.2.8、MySQL等依賴
   # 複製程式碼到伺服器
   ```

2. **安裝並設定**
   ```bash
   bundle install --deployment --without development test
   
   # 複製並編輯配置檔案
   cp config/database.yml.default config/database.yml
   # 編輯 config/database.yml 設定生產環境資料庫
   # 編輯 config/memorial.yml 設定功能開關
   
   # 產生 secret key
   bundle exec rails secret
   # 將產生的key設為 SECRET_KEY_BASE 環境變數
   
   RAILS_ENV=production rails db:migrate
   RAILS_ENV=production rails assets:precompile
   ```

3. **啟動服務**
   ```bash
   # 使用Unicorn
   bundle exec unicorn -c unicorn.conf.rb -E production -D
   
   # 或使用systemd、supervisor等程序管理工具
   ```

### 健康檢查

應用程式提供健康檢查端點：
- `GET /health` - 返回 200 OK 狀態

## 設定說明

### 留言功能開關

可透過以下方式控制留言功能：

1. **環境變數**（優先級最高）
   ```bash
   export MEMORIAL_COMMENTING_ENABLED=false  # 關閉留言
   export MEMORIAL_COMMENTING_ENABLED=true   # 開啟留言
   ```

2. **設定檔案** `config/memorial.yml`
   ```yaml
   production:
     features:
       commenting_enabled: false  # 關閉留言
   ```

當關閉留言功能時：
- 首頁不顯示「留言」按鈕
- `/say` 路由被阻擋，重導向至首頁
- 無法提交新留言

### 安全設定

應用程式已啟用以下安全機制：
- CSRF保護
- XSS輸入清理
- Content Security Policy
- 安全標頭設定
- 輸入驗證

## 管理工具

### Rake Tasks

本專案提供以下管理工具：

#### 匯出留言 (`memorial:export`)

將所有留言匯出為 JSON 或 CSV 格式：

```bash
# 匯出為 JSON 格式（預設）
rails memorial:export

# 匯出為 CSV 格式
rails memorial:export[csv]
```

輸出檔案會儲存在 `backup/` 目錄，檔名包含時間戳記。

#### 清空留言 (`memorial:clear`)

安全地清空所有留言，包含確認步驟和自動備份：

```bash
rails memorial:clear
```

執行流程：
1. 顯示留言數量警告
2. 詢問是否建立自動備份（預設：是）
3. 最終確認刪除操作
4. 清空留言並重置資料庫 ID 計數器

**重要提醒**：刪除操作無法復原，建議先建立備份。

詳細說明請參考 [TASK_README.md](TASK_README.md)。

## 測試

```bash
# 執行所有測試
rails test

# 執行特定測試
rails test test/models/message_test.rb
rails test test/controllers/pages_controller_test.rb

# 執行 rake task 測試
rails test test/lib/tasks/

# 系統測試（需要Chrome/Firefox）
rails test:system
```

## 貢獻

本網站感謝以下組織、個人之貢獻：華人民主書院、Ginger、Iris、Joy Hsu、蕭新晟、雨蒼。

## 授權

本專案採用 MIT License 授權 - 詳見 [LICENSE](LICENSE) 檔案。

## 支援

如有問題或建議，請透過 GitHub Issues 回報。