# Telco Customer Churn — Plano de Análises (MySQL + BI)

Este projeto utiliza o [Conjunto de dados público de retenção e controle de contratos em uma empresa de telecomunicação](https://www.kaggle.com/datasets/blastchar/telco-customer-churn), disponível no Kaggle.

O dataset reúne informações de rotatividade para controle de retenção de clientes em uma empresa do ramo de telecomunicação, incluindo dados de:

* customerID — ID do cliente
* gender — Gênero
* SeniorCitizen — Idoso (0/1)
* Partner — Parceiro (Yes/No)
* Dependents — Dependentes (Yes/No)
* tenure — Tempo de permanência (meses)
* PhoneService — Serviço telefônico
* MultipleLines — Múltiplas linhas / Sem linha telefônica
* InternetService — Serviço de internet (DSL/Fiber/No)
* OnlineSecurity, OnlineBackup, DeviceProtection, TechSupport — Add-ons
* StreamingTV, StreamingMovies — Streaming
* Contract — Tipo de contrato (Month-to-month / One year / Two year)
* PaperlessBilling — Faturamento digital
* PaymentMethod — Método de pagamento
* MonthlyCharges — Cobranças mensais
* TotalCharges — Cobranças totais
* Churn — Cancelamento (Yes/No)
  
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
LINES  TERMINATED BY '\r\n'   
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

# Qual é a taxa de churn global?

Definição: Percentual de clientes que cancelaram (`Churn = 'Yes'`) em relação ao total de clientes.

Fórmula (conceito): `churn_global = (n_cancelados / n_total) * 100`

## Query utilizada no MySQL

```sql
-- Qual é a taxa de churn global?

WITH contagem AS (
  SELECT
    COUNT(customerID) AS customers,
    SUM(Churn='Yes')  AS customers_churn 
  FROM customer_churn
)
SELECT ROUND(customers_churn * 100.0 / customers, 2) AS churn_global_pct
FROM contagem;
```

No MySQL, a expressão `Churn = 'Yes'` vira **1/0** (verdadeiro/falso). A média (`AVG`) desses valores retorna diretamente a **fração de cancelados**, evitando erros de **divisão inteira** e deixando o SQL mais limpo.

<p align="center">
  <img src="docs/customer_churn_taxaglobal.png" alt="Contagem de clientes Olist" style="max-width:80%;">
</p>

# Como o churn varia por tipo de contrato (Monthly / One year / Two year)?

Pergunta: Como o churn varia entre `Month-to-month`, `One year` e `Two year`?

Métrica utilizada: taxa de churn por contrato = (cancelados do contrato / clientes do contrato) × 100

## Query utilizada no MySQL

```sql
SELECT  Contract,
		COUNT(customerID) AS customers,
		SUM(churn='Yes')  AS customers_churn,
        ROUND(SUM(churn = 'Yes')*100 / COUNT(customerID),2) AS churn_rate 
FROM customer_churn
GROUP BY contract
ORDER BY churn_rate DESC
```

<p align="center">
  <img src="docs/customer_churn_contract.png" alt="Contagem de clientes Olist" style="max-width:80%;">
</p>

# Método de pagamento (electronic check, credit card, bank transfer, mailed check) influencia o churn?

Pergunta: Métodos como `Electronic check`, `Credit card (automatic)`, `Bank transfer (automatic)` e `Mailed check` influenciam o churn?

Métrica: taxa de churn por método = (cancelados do método / clientes do método) × 100.

## Query utilizada no MySQL

```sql
SELECT  PaymentMethod,
		COUNT(customerID) AS customers,
		SUM(churn='Yes')  AS customers_churn,
        ROUND(SUM(churn = 'Yes')*100 / COUNT(customerID),2) AS churn_rate 
FROM customer_churn
GROUP BY PaymentMethod
ORDER BY churn_rate DESC
```
<p align="center">
  <img src="docs/customer_churn_paymentmethod.png" alt="Contagem de clientes Olist" style="max-width:80%;">
</p>
