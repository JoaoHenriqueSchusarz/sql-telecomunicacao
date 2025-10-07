# Telco Customer Churn — Plano de Análises (MySQL + BI)

## Objetivo

Medir e explicar o churn de clientes e identificar segmentos de risco e alavancas de retenção (contrato, método de pagamento, serviços, preço e tempo de casa).

## Perguntas de negócio (o que vou responder)

* Qual é a taxa de churn global?
* Como o churn varia por tipo de contrato (Monthly / One year / Two year)?
* Método de pagamento (electronic check, credit card, bank transfer, mailed check) influencia o churn?
* Qual o efeito de InternetService (DSL/Fiber/None) e de add-ons (OnlineSecurity, TechSupport, etc.) no churn?
* SeniorCitizen, Partner, Dependents alteram a probabilidade de churn?
* Faixas de preço (MonthlyCharges) x churn: onde o risco é maior?
* Tenure (tempo de casa) x churn: qual a curva de sobrevivência? Onde ocorre o “vale” de maior risco?
* Quais são as top 5 combinações de serviços com maior churn?
* Quais segmentos têm churn acima da média (uplift) e devem ser priorizados?
* Qual a perda de receita recorrente associada ao churn (aproximação)?
* Entre clientes “Month-to-month”, quais métodos de pagamento elevam/baixam o risco?
* PaperlessBilling impacta churn?

# Tratamento e Qualidade dos Dados

Fonte: WA_Fn-UseC_-Telco-Customer-Churn.csv (Kaggle)
Objetivo do tratamento: garantir tipos corretos, lidar com valores vazios e inconsistências de formatação para viabilizar análises confiáveis no SQL/BI.

## Padronizações aplicadas

### Tipos numéricos

* MonthlyCharges → DECIMAL(7,2) (ajuste para evitar estouro; ex.: 108.50).
* TotalCharges → DECIMAL(10,2) (pode acumular valores altos).
* SeniorCitizen → INT (0/1).

### Valores vazios

Conversão de strings vazias ('') em NULL para MonthlyCharges e TotalCharges.

### Formatação numérica

* Troca de vírgula por ponto como separador decimal.
* Remoção de espaços perdidos dentro dos números (ex.: 69 994.8 → 69994.80).
* TRIM para retirar espaços extras nas extremidades.

### Observação

Linhas com tenure = 0 podem ter TotalCharges vazio por serem clientes muito novos.

## Carga com limpeza (MySQL)


```sql
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/tele_churn/Telco-Customer-Churn.csv'
INTO TABLE customer_churn
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','  OPTIONALLY ENCLOSED BY '"'
LINES  TERMINATED BY '\n'
IGNORE 1 LINES
(
  customerID, gender, SeniorCitizen, Partner, Dependents, tenure,
  PhoneService, MultipleLines, InternetService, OnlineSecurity, OnlineBackup,
  DeviceProtection, TechSupport, StreamingTV, StreamingMovies, Contract,
  PaperlessBilling, PaymentMethod,
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
```

