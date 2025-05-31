# Memorial App - Rake Tasks

這個專案包含兩個自訂的 Rake tasks 來管理紀念留言。

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

### 2. 清空留言 (`memorial:clear`)

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

兩個 tasks 都有完整的測試覆蓋：

```bash
# 執行匯出功能測試
rails test test/lib/tasks/memorial_rake_test.rb

# 執行清空功能測試  
rails test test/lib/tasks/memorial_clear_test.rb

# 執行所有 task 測試
rails test test/lib/tasks/
```

## 檔案結構

```
lib/tasks/memorial.rake           # 主要 task 定義
test/lib/tasks/memorial_rake_test.rb      # 匯出功能測試
test/lib/tasks/memorial_clear_test.rb     # 清空功能測試
backup/                          # 匯出檔案儲存目錄
```