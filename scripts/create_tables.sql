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
LINES  TERMINATED BY '\n'
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

SELECT * FROM customer_churn LIMIT 10;
SELECT COUNT(*) AS total_rows FROM customer_churn;
SELECT COUNT(*) AS missing_total_charges FROM customer_churn WHERE TotalCharges IS NULL;
SELECT COUNT(*) AS missing_tenure FROM customer_churn WHERE tenure IS NULL;
SELECT COUNT(*) AS missing_monthly_charges FROM customer_churn WHERE MonthlyCharges IS NULL;
SELECT COUNT(*) AS missing_senior_citizen FROM customer_churn WHERE SeniorCitizen IS NULL;
SELECT COUNT(*) AS missing
FROM customer_churn
WHERE   
    customerID IS NULL

