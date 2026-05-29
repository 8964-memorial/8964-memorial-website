# Memorial App - Rake Tasks

這個專案包含三個自訂的 Rake tasks 來管理紀念留言。

## 可用的 Tasks

### 1. 匯出留言 (`memorial:export`)

將所有留言匯出為 JSON 或 CSV 格式，檔案會儲存到 `backup/` 目錄。

**使用方式：**
```bash
# 匯出為 JSON 格式（預設）
rails memorial:export

# 明確指定 JSON 格式  
rails memorial:export[json]

# 匯出為 CSV 格式
rails memorial:export[csv]
```

**輸出檔案：**
- JSON: `backup/memorial_messages_YYYYMMDD_HHMMSS.json`
- CSV: `backup/memorial_messages_YYYYMMDD_HHMMSS.csv`

**功能特色：**
- 自動建立 `backup/` 目錄
- 檔名包含時間戳記避免覆蓋
- JSON 格式包含完整的資料結構
- CSV 格式使用中文標頭（ID、姓名、留言內容、建立時間、更新時間）
- 空資料庫時會顯示提示訊息

### 2. 生成靜態網站 (`memorial:static`)

將目前留言打包成一份純靜態 HTML 網站，並壓縮成 ZIP。適合在無法執行 Rails 的環境（或備援）上託管。

**使用方式：**
```bash
rails memorial:static
```

**執行流程：**
1. 重新建立資料庫連線，讀取目前所有留言
2. 產生 `static_output/index.html`（留言由前端 JavaScript 隨機排序顯示）
3. 複製圖片、CSS 等靜態資源到 `static_output/assets/`
4. 壓縮成帶時間戳的 ZIP 放到 `static_zip/`

**輸出：**
- 靜態檔案目錄：`static_output/`
- 壓縮檔：`static_zip/memorial_static_YYYYMMDD_HHMMSS.zip`

**安全特色：**
- 內嵌進 inline `<script>` 的留言 JSON 會把 `<`、`>`、`&` 做 unicode 跳脫（`<` 等），避免留言內容中的 `</script>` 破出標籤造成 XSS。

**注意：** 需安裝 `rubyzip` gem（已在 Gemfile）以支援 ZIP 壓縮。

### 3. 清空留言 (`memorial:clear`)

安全地清空所有留言，包含確認步驟和自動備份功能。

**使用方式：**
```bash
rails memorial:clear
```

**執行流程：**
1. 顯示目前留言數量警告
2. 詢問是否要自動建立備份（預設：是）
3. 如選擇備份，會同時建立 JSON 和 CSV 備份檔
4. 最終確認是否要刪除所有留言
5. 執行刪除並重置資料庫 ID 計數器

**安全特色：**
- 雙重確認機制
- 自動備份建議（可選擇跳過）
- 備份失敗時會暫停並提供手動備份指令
- 清空後會重置 MySQL 的 AUTO_INCREMENT 計數器
- 空資料庫時會顯示提示訊息

**重要提醒：**
- 刪除操作無法復原
- 建議在刪除前建立備份
- 支援 MySQL 資料庫的 ID 重置功能

## 測試

三個 tasks 都有測試覆蓋：

```bash
# 匯出 + 靜態網站功能測試
rails test test/lib/tasks/memorial_rake_test.rb

# 清空功能測試
rails test test/lib/tasks/memorial_clear_test.rb

# 執行所有 task 測試
rails test test/lib/tasks/
```

注意：這兩個測試類別刻意設 `use_transactional_tests = false`（tasks 會跑 DDL 與重建連線），詳見 CLAUDE.md 的測試套件注意事項。

## 檔案結構

```
lib/tasks/memorial.rake                   # export / static / clear task 定義
test/lib/tasks/memorial_rake_test.rb      # 匯出 + 靜態網站測試
test/lib/tasks/memorial_clear_test.rb     # 清空測試
backup/                                   # 匯出 / 備份檔輸出目錄
static_output/                            # 靜態網站產出目錄
static_zip/                               # 靜態網站 ZIP 輸出目錄
```