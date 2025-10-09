CREATE DATABASE IF NOT EXISTS tele_churn   CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci

USE tele_churn;

CREATE TABLE customer_churn (
customerID          CHAR(10) NOT NULL PRIMARY KEY,
gender              VARCHAR(6) NOT NULL,
SeniorCitizen       INT,
Partner             VARCHAR(4) NOT NULL,
Dependents          VARCHAR(4) NOT NULL,
tenure              INT,
PhoneService        VARCHAR(4) NOT NULL,
MultipleLines       VARCHAR(20) NOT NULL,
InternetService     VARCHAR(12) NOT NULL,
OnlineSecurity      VARCHAR(20) NOT NULL,
OnlineBackup        VARCHAR(20) NOT NULL,
DeviceProtection    VARCHAR(20) NOT NULL,
TechSupport         VARCHAR(20) NOT NULL,
StreamingTV         VARCHAR(20) NOT NULL,
StreamingMovies     VARCHAR(20) NOT NULL,
Contract            VARCHAR(20) NOT NULL,
PaperlessBilling    VARCHAR(4) NOT NULL,
PaymentMethod       VARCHAR(30) NOT NULL,
MonthlyCharges      DECIMAL(7,2) NOT NULL,
TotalCharges        DECIMAL(10,2) NULL,
Churn               VARCHAR(4) NOT NULL
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/tele_churn/Telco-Customer-Churn.csv'
INTO TABLE customer_churn
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','  OPTIONALLY ENCLOSED BY '"'
LINES  TERMINATED BY '\r\n'   
IGNORE 1 LINES
(
  customerID,
  gender,
  SeniorCitizen,
  Partner,
  Dependents,
  tenure,
  PhoneService,
  MultipleLines,
  InternetService,
  OnlineSecurity,
  OnlineBackup,
  DeviceProtection,
  TechSupport,
  StreamingTV,
  StreamingMovies,
  Contract,
  PaperlessBilling,
  PaymentMethod,
  @MonthlyCharges,     
  @TotalCharges,
  Churn
)
SET
  MonthlyCharges = CASE
                     WHEN TRIM(@MonthlyCharges)='' THEN NULL
                     ELSE CAST(REPLACE(REPLACE(TRIM(@MonthlyCharges),' ',''), ',', '.') AS DECIMAL(7,2))
                   END,
  TotalCharges   = CASE
                     WHEN TRIM(@TotalCharges)='' THEN NULL
                     ELSE CAST(REPLACE(REPLACE(TRIM(@TotalCharges),' ',''), ',', '.') AS DECIMAL(10,2))
                   END;
-- Tratamento dos dados nulos, remoção de espaços perdidos dentro dos números (ex.: 69 994.8 → 69994.80)

-- Os dados foram obtidos do Kaggle: https://www.kaggle.com/datasets/blastchar/telco-customer-churn
-- O arquivo CSV foi salvo na pasta de Uploads do MySQL para permitir a carga via comando LOAD DATA INFILE

-- Verificação dos dados carregados
SELECT * FROM customer_churn LIMIT 10;

-- Verificação de dados nulos
SELECT COUNT(*) AS Total_Null_MonthlyCharges FROM customer_churn WHERE MonthlyCharges IS NULL;
SELECT COUNT(*) AS Total_Null_TotalCharges   FROM customer_churn WHERE TotalCharges IS NULL

-- Base limpa + flag numérica de churn
CREATE OR REPLACE VIEW telco_clean AS
SELECT *,
       CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END AS is_churn
FROM customer_churn;

-- Faixas de preço e tenure
CREATE OR REPLACE VIEW telco_price_tenure AS
SELECT *,
  CASE
    WHEN MonthlyCharges < 30 THEN '<30'
    WHEN MonthlyCharges < 60 THEN '30–59'
    WHEN MonthlyCharges < 90 THEN '60–89'
    ELSE '90+'
  END AS price_band,
  CASE
    WHEN tenure <= 1 THEN '0–1'
    WHEN tenure <= 5 THEN '2–5'
    WHEN tenure <= 11 THEN '6–11'
    WHEN tenure <= 23 THEN '12–23'
    WHEN tenure <= 47 THEN '24–47'
    ELSE '48+'
  END AS tenure_band
FROM telco_clean;