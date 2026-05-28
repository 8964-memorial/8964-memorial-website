# 8964 Memorial Website

紀念六四事件的網站，提供留言點燈功能讓用戶表達追思之意。

## 功能特色

- **首頁展示**：隨機顯示所有紀念留言
- **留言功能**：可開關的留言系統，支援姓名和20字內容留言
- **響應式設計**：支援桌面和行動裝置
- **安全防護**：包含CSRF保護、XSS防護、Content Security Policy等
- **Facebook活動連結**：整合相關紀念活動資訊

## 技術規格

- **Framework**: Ruby on Rails 7.2.3.1（7.2 系列維持中，未升 8）
- **Ruby Version**: 3.4.4
- **Database**: MySQL
- **Web Server**: Unicorn (生產環境)
- **CSS**: SCSS with Sass
- **JavaScript**: Stimulus + Turbo (Hotwire)
- **防灌水**: rack-attack 節流 + honeypot 隱藏欄位

## 安裝與開發

### 系統需求

- Ruby 3.4.4
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

- **測試**: `bin/rails test`
- **相依套件 CVE 掃描**: `bundle exec bundler-audit check --update`
- **應用程式靜態安全掃描**: `bundle exec brakeman`
- **Console**: `bin/rails console`

## 部署

### 配置設定

#### 資料庫配置

複製並編輯資料庫配置檔案：

```bash
cp config/database.yml.default config/database.yml
```

編輯 `config/database.yml` 生產環境設定（`database.yml` 本身已在 `.gitignore` 中、不會進版控）：

```yaml
production:
  adapter: mysql2
  encoding: utf8mb4
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  database: memorial_production
  username: <%= ENV.fetch("MEMORIAL_DB_USERNAME", "memorial") %>
  password: <%= ENV.fetch("MEMORIAL_DB_PASSWORD") if Rails.env.production? %>
  host: localhost
```

`MEMORIAL_DB_PASSWORD` 在 production 才會被讀取（缺值會 fail fast），dev/test 不受影響。

#### 環境變數

在生產環境中，必要 / 可選的環境變數：

```bash
# 資料庫（必要）
MEMORIAL_DB_PASSWORD=高強度密碼
MEMORIAL_DB_USERNAME=memorial   # 可選，預設 memorial

# Rails 必要
RAILS_ENV=production
SECRET_KEY_BASE=...              # 或透過 config/credentials.yml.enc + RAILS_MASTER_KEY

# 留言功能開關（可選；ENV 優先於 config/memorial.yml）
MEMORIAL_COMMENTING_ENABLED=true  # true/false

# 靜態檔案服務（容器/反向代理情境）
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
```

#### 留言功能配置

編輯 `config/memorial.yml` 控制留言功能：

```yaml
production:
  features:
    commenting_enabled: true  # 設為false關閉留言功能
```

### Docker 部署

範例 `Dockerfile`：

```dockerfile
FROM ruby:3.4.4

WORKDIR /app

# mysql2 0.5.x 在 Ruby 3.4 (C23) 下需要 -std=gnu17 才能編譯
# .bundle/config 已 commit 該設定，bundle install 會自動採用
COPY Gemfile Gemfile.lock .ruby-version .bundle/ .bundle/
COPY . .

RUN bundle install --deployment --without development test
RUN rails assets:precompile

EXPOSE 3000

CMD ["bundle", "exec", "unicorn", "-c", "unicorn.conf.rb"]
```

### 傳統部署

1. **在伺服器上準備環境**
   ```bash
   # 安裝 Ruby 3.4.4、MySQL 等依賴
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

應用程式已啟用以下安全機制（詳見 2026-05 強化）：

- **CSRF 保護**（`protect_from_forgery`）
- **XSS 輸入清理**（Message 儲存前 `sanitize`） + **ERB 自動跳脫輸出**
- **Content Security Policy**：`script_src :self`、每請求隨機 nonce
- **防灌水**：`rack-attack` 對 `POST /say` 節流（5/分、30/日、全站 300/5 分），加上表單 honeypot 隱藏欄位
- **傳輸層**：production 啟用 `assume_ssl + force_ssl`，cookie 帶 `Secure`、回應送 HSTS（搭配 Cloudflare Flexible SSL；建議升級為 Full(strict)）
- **其他標頭**：`X-Frame-Options: DENY`、`X-Content-Type-Options: nosniff`、`Referrer-Policy: strict-origin-when-cross-origin`、最小化 `Permissions-Policy`
- **密鑰管理**：`config/master.key`、`config/database.yml` 已 gitignore 且確認從未進入 git 歷史；DB 密碼從 `MEMORIAL_DB_PASSWORD` 環境變數讀取
- **靜態匯出**：`memorial:static` 在內嵌 `<script>` 時 unicode-escape 留言中的 `<>&`，避免 `</script>` 破出

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

#### 生成靜態網站 (`memorial:static`)

將動態網站打包成靜態 HTML 檔案，並自動壓縮為 ZIP 檔案：

```bash
rails memorial:static
```

功能說明：
1. 生成包含所有留言的靜態 HTML 頁面
2. 複製所有必要的靜態資源（圖片、CSS等）
3. 自動打包成帶日期後綴的 ZIP 檔案（如：`memorial_static_20250608_143522.zip`）
4. 靜態檔案可直接部署到任何靜態網站託管服務

輸出：
- 靜態檔案目錄：`static_output/`
- 壓縮檔案：專案根目錄的 `memorial_static_[時間戳].zip`

**注意**：需要先安裝 `rubyzip` gem 以支援 ZIP 壓縮功能。

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