-- ============================================================
-- clean_bank_churners_sqlite.sql
-- 信用卡客戶流失分析 — 資料清洗（SQLite 版）
--
-- 用法（在終端機）:
--     sqlite3 churn.db < clean_bank_churners_sqlite.sql
-- 之後就能用任何工具（DB Browser、Python 的 sqlite3 / pandas）查 clean_bank_churners。
--
-- SQLite 與 DuckDB 的差異:
--   1. SQLite 不能直接對 CSV 下 SQL，要先把 CSV 匯入成資料表。
--   2. 匯入後欄位預設是 TEXT，所以數值欄用 CAST 轉成 INTEGER / REAL，
--      後面算 AVG、做大小比較才正確。
-- ============================================================

-- 0) 匯入 CSV
--    下面三行是 sqlite3 CLI 的「點命令」(dot command)，不是標準 SQL。
--    目標表不存在時，.import 會用 CSV 第一列當欄名自動建表（全部 TEXT），
--    第二列起當資料；我們在第 2 步用 CAST 處理型別。
.mode csv
.import BankChurners.csv raw_bank_churners

-- ------------------------------------------------------------
-- 1) 資料品質檢查（清洗前先看一眼）
-- ------------------------------------------------------------

-- 筆數 + 整體流失率
SELECT
    COUNT(*) AS n_rows,
    ROUND(AVG(CASE WHEN TRIM(Attrition_Flag) = 'Attrited Customer' THEN 1.0 ELSE 0 END), 3) AS churn_rate
FROM raw_bank_churners;

-- 缺漏值：COUNT(*) - COUNT(欄位) 就是該欄的 NULL 數
SELECT
    COUNT(*) - COUNT(Income_Category) AS missing_income,
    COUNT(*) - COUNT(Education_Level) AS missing_education,
    COUNT(*) - COUNT(Marital_Status)  AS missing_marital
FROM raw_bank_churners;

-- 重複客戶：同一個 CLIENTNUM 是否出現多次（空結果 = 沒有重複）
SELECT CLIENTNUM, COUNT(*) AS cnt
FROM raw_bank_churners
GROUP BY CLIENTNUM
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- 2) 清洗：建立乾淨的 VIEW
--    做四件事：
--      a. 只保留有意義的欄位 — 不選 CLIENTNUM 與兩個 Naive_Bayes_Classifier 欄位
--         （後者是事先算好的預測結果，留著會造成資料洩漏 data leakage）。
--      b. 移除 Avg_Open_To_Buy — 它 = Credit_Limit - Total_Revolving_Bal，
--         與 Credit_Limit 幾乎完全共線（r=0.996），會讓迴歸係數失真。
--      c. TRIM() 清掉文字欄位多餘空白，避免 "Male" 與 "Male " 被當成兩組。
--      d. CAST 把數值欄轉回正確型別；CASE WHEN 建立目標欄位 Churn。
-- ------------------------------------------------------------
DROP VIEW IF EXISTS clean_bank_churners;
CREATE VIEW clean_bank_churners AS
SELECT
    CAST(Customer_Age AS INTEGER)             AS Customer_Age,
    TRIM(Gender)                              AS Gender,
    CAST(Dependent_count AS INTEGER)          AS Dependent_count,
    TRIM(Education_Level)                     AS Education_Level,
    TRIM(Marital_Status)                      AS Marital_Status,
    TRIM(Income_Category)                     AS Income_Category,
    TRIM(Card_Category)                       AS Card_Category,
    CAST(Months_on_book AS INTEGER)           AS Months_on_book,
    CAST(Total_Relationship_Count AS INTEGER) AS Total_Relationship_Count,
    CAST(Months_Inactive_12_mon AS INTEGER)   AS Months_Inactive_12_mon,
    CAST(Contacts_Count_12_mon AS INTEGER)    AS Contacts_Count_12_mon,
    CAST(Credit_Limit AS REAL)                AS Credit_Limit,
    CAST(Total_Revolving_Bal AS INTEGER)      AS Total_Revolving_Bal,
    -- Avg_Open_To_Buy 刻意移除（見上方說明 b）
    CAST(Total_Amt_Chng_Q4_Q1 AS REAL)        AS Total_Amt_Chng_Q4_Q1,
    CAST(Total_Trans_Amt AS INTEGER)          AS Total_Trans_Amt,
    CAST(Total_Trans_Ct AS INTEGER)           AS Total_Trans_Ct,
    CAST(Total_Ct_Chng_Q4_Q1 AS REAL)         AS Total_Ct_Chng_Q4_Q1,
    CAST(Avg_Utilization_Ratio AS REAL)       AS Avg_Utilization_Ratio,
    TRIM(Attrition_Flag)                      AS Attrition_Flag,
    CASE WHEN TRIM(Attrition_Flag) = 'Attrited Customer' THEN 1 ELSE 0 END AS Churn
FROM raw_bank_churners;

-- 確認：清洗後筆數、欄數、流失/留存的平均交易次數
SELECT COUNT(*) AS n_rows FROM clean_bank_churners;

SELECT
    Attrition_Flag,
    ROUND(AVG(Total_Trans_Ct), 1) AS avg_trans_ct
FROM clean_bank_churners
GROUP BY Attrition_Flag;
