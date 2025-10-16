-- Flag numérica de churn
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

-- Qual é a taxa de churn global?

WITH contagem AS (
  SELECT
    COUNT(customerID) AS customers,
    SUM(Churn='Yes')  AS customers_churn 
  FROM customer_churn
)
SELECT ROUND(customers_churn * 100.0 / customers, 2) AS churn_global_pct
FROM contagem;
-- Qual é a taxa de churn por faixa de preço?
WITH contagem AS (
  SELECT
    price_band,
    COUNT(customerID) AS customers,
    SUM(Churn='Yes')  AS customers_churn 
  FROM telco_price_tenure
  GROUP BY price_band
)
SELECT price_band,
       ROUND(customers_churn * 100.0 / customers, 2) AS churn_pct
FROM contagem
ORDER BY price_band;
-- Como o churn varia por tipo de contrato (Monthly / One year / Two year)?
SELECT  Contract,
		COUNT(customerID) AS customers,
		SUM(churn='Yes')  AS customers_churn,
        ROUND(SUM(churn = 'Yes')*100 / COUNT(customerID),2) AS churn_rate 
FROM customer_churn
GROUP BY contract
ORDER BY churn_rate DESC;
-- Qual o efeito de InternetService (DSL/Fiber/None) e de add-ons (OnlineSecurity, TechSupport, etc.) no churn?

CREATE OR REPLACE VIEW telco_features AS
SELECT
  customerID,
  is_churn,
  InternetService,
  CASE WHEN OnlineSecurity   = 'Yes' THEN 1 ELSE 0 END AS f_Security,
  CASE WHEN OnlineBackup     = 'Yes' THEN 1 ELSE 0 END AS f_Backup,
  CASE WHEN DeviceProtection = 'Yes' THEN 1 ELSE 0 END AS f_Protection,
  CASE WHEN TechSupport      = 'Yes' THEN 1 ELSE 0 END AS f_Support,
  CASE WHEN StreamingTV      = 'Yes' THEN 1 ELSE 0 END AS f_TV,
  CASE WHEN StreamingMovies  = 'Yes' THEN 1 ELSE 0 END AS f_Movies
FROM telco_clean;

WITH g AS (
  SELECT SUM(is_churn)/COUNT(*) AS churn_global FROM telco_features
)
SELECT * FROM (
  SELECT 'OnlineSecurity' AS feature,
         SUM(f_Security)                                      AS users_with,
         ROUND(SUM(CASE WHEN f_Security=1 THEN is_churn END) / NULLIF(SUM(f_Security),0),4)           AS churn_with,
         ROUND(SUM(CASE WHEN f_Security=0 THEN is_churn END) / NULLIF(SUM(1-f_Security),0),4)         AS churn_without,
         ROUND(
           (SUM(CASE WHEN f_Security=1 THEN is_churn END)/NULLIF(SUM(f_Security),0)) -
           (SUM(CASE WHEN f_Security=0 THEN is_churn END)/NULLIF(SUM(1-f_Security),0)),4)             AS uplift,
         (SELECT churn_global FROM g) AS churn_global
  FROM telco_features
  UNION ALL
  SELECT 'OnlineBackup',
         SUM(f_Backup),
         ROUND(SUM(CASE WHEN f_Backup=1 THEN is_churn END)/NULLIF(SUM(f_Backup),0),4),
         ROUND(SUM(CASE WHEN f_Backup=0 THEN is_churn END)/NULLIF(SUM(1-f_Backup),0),4),
         ROUND(
           (SUM(CASE WHEN f_Backup=1 THEN is_churn END)/NULLIF(SUM(f_Backup),0)) -
           (SUM(CASE WHEN f_Backup=0 THEN is_churn END)/NULLIF(SUM(1-f_Backup),0)),4),
         (SELECT churn_global FROM g)
  FROM telco_features
  UNION ALL
  SELECT 'DeviceProtection',
         SUM(f_Protection),
         ROUND(SUM(CASE WHEN f_Protection=1 THEN is_churn END)/NULLIF(SUM(f_Protection),0),4),
         ROUND(SUM(CASE WHEN f_Protection=0 THEN is_churn END)/NULLIF(SUM(1-f_Protection),0),4),
         ROUND(
           (SUM(CASE WHEN f_Protection=1 THEN is_churn END)/NULLIF(SUM(f_Protection),0)) -
           (SUM(CASE WHEN f_Protection=0 THEN is_churn END)/NULLIF(SUM(1-f_Protection),0)),4),
         (SELECT churn_global FROM g)
  FROM telco_features
  UNION ALL
  SELECT 'TechSupport',
         SUM(f_Support),
         ROUND(SUM(CASE WHEN f_Support=1 THEN is_churn END)/NULLIF(SUM(f_Support),0),4),
         ROUND(SUM(CASE WHEN f_Support=0 THEN is_churn END)/NULLIF(SUM(1-f_Support),0),4),
         ROUND(
           (SUM(CASE WHEN f_Support=1 THEN is_churn END)/NULLIF(SUM(f_Support),0)) -
           (SUM(CASE WHEN f_Support=0 THEN is_churn END)/NULLIF(SUM(1-f_Support),0)),4),
         (SELECT churn_global FROM g)
  FROM telco_features
  UNION ALL
  SELECT 'StreamingTV',
         SUM(f_TV),
         ROUND(SUM(CASE WHEN f_TV=1 THEN is_churn END)/NULLIF(SUM(f_TV),0),4),
         ROUND(SUM(CASE WHEN f_TV=0 THEN is_churn END)/NULLIF(SUM(1-f_TV),0),4),
         ROUND(
           (SUM(CASE WHEN f_TV=1 THEN is_churn END)/NULLIF(SUM(f_TV),0)) -
           (SUM(CASE WHEN f_TV=0 THEN is_churn END)/NULLIF(SUM(1-f_TV),0)),4),
         (SELECT churn_global FROM g)
  FROM telco_features
  UNION ALL
  SELECT 'StreamingMovies',
         SUM(f_Movies),
         ROUND(SUM(CASE WHEN f_Movies=1 THEN is_churn END)/NULLIF(SUM(f_Movies),0),4),
         ROUND(SUM(CASE WHEN f_Movies=0 THEN is_churn END)/NULLIF(SUM(1-f_Movies),0),4),
         ROUND(
           (SUM(CASE WHEN f_Movies=1 THEN is_churn END)/NULLIF(SUM(f_Movies),0)) -
           (SUM(CASE WHEN f_Movies=0 THEN is_churn END)/NULLIF(SUM(1-f_Movies),0)),4),
         (SELECT churn_global FROM g)
  FROM telco_features
) t
ORDER BY uplift DESC;


-- Só por tipo de internet
SELECT
		InternetService,
		COUNT(customerID) AS customers,
        ROUND(SUM(churn = 'Yes')*100 / COUNT(customerID),2) AS churn_rate 
FROM customer_churn
GROUP BY InternetService
ORDER BY churn_rate DESC;

-- OnlineSecurity
SELECT
  OnlineSecurity,
  COUNT(*) AS customers,
  ROUND( AVG(Churn='Yes') * 100, 2 ) AS churn_rate_pct
FROM customer_churn
WHERE InternetService IN ('DSL','Fiber optic')
  AND OnlineSecurity <> 'No internet service'
GROUP BY OnlineSecurity;

-- DeviceProtection
SELECT DeviceProtection,
		COUNT(customerID) AS customers,
        ROUND(SUM(churn = 'Yes')*100 / COUNT(customerID),2) AS churn_rate
FROM customer_churn
WHERE InternetService IN ('DSL','Fiber optic')
  AND DeviceProtection <> 'No internet service'
GROUP BY DeviceProtection;

-- TechSupport
SELECT TechSupport,
		COUNT(customerID) AS customers,
        ROUND(SUM(churn = 'Yes')*100 / COUNT(customerID),2) AS churn_rate
FROM customer_churn
WHERE InternetService IN ('DSL','Fiber optic')
  AND TechSupport <> 'No internet service'
GROUP BY TechSupport;

-- StreamingMovies
SELECT StreamingMovies,
		COUNT(customerID) AS customers,
        ROUND(SUM(churn = 'Yes')*100 / COUNT(customerID),2) AS churn_rate
FROM customer_churn
WHERE InternetService IN ('DSL','Fiber optic')
  AND StreamingMovies <> 'No internet service'
GROUP BY StreamingMovies;

-- StreamingTV
SELECT StreamingTV,
		COUNT(customerID) AS customers,
        ROUND(SUM(churn = 'Yes')*100 / COUNT(customerID),2) AS churn_rate
FROM customer_churn
WHERE InternetService IN ('DSL','Fiber optic')
  AND StreamingTV <> 'No internet service'
GROUP BY StreamingTV;

-- Método de pagamento (electronic check, credit card, bank transfer, mailed check) influencia o churn?

SELECT  PaymentMethod,
		COUNT(customerID) AS customers,
		SUM(churn='Yes')  AS customers_churn,
        ROUND(SUM(churn = 'Yes')*100 / COUNT(customerID),2) AS churn_rate 
FROM customer_churn
GROUP BY PaymentMethod
ORDER BY churn_rate DESC;

-- Qual é a taxa de churn por faixa de tenure?
WITH contagem AS (
    SELECT
        tenure_band,
        COUNT(customerID) AS customers,
        SUM(Churn='Yes')  AS customers_churn 
    FROM telco_price_tenure
    GROUP BY tenure_band
    )
SELECT tenure_band,
       ROUND(customers_churn * 100.0 / customers, 2) AS churn_pct
FROM contagem
ORDER BY FIELD(tenure_band, '0–1', '2–5', '
'6–11', '12–23', '24–47', '48+');8+');
-- Quais são os 5 serviços mais associados ao churn?  