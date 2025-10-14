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

## Qual o efeito de InternetService (DSL/Fiber/None) e de Add-ons (OnlineSecurity, TechSupport, etc.) no churn?

### Criação da view `telco_features`
Para analisar todos os add-ons de forma comparável, criei uma view que transforma cada recurso em flags binárias (0/1). Assim fica simples contar bases, calcular taxas e comparar “tem” vs “não tem”.

```sql
CREATE OR REPLACE VIEW telco_features AS
SELECT
  customerID,
  is_churn,                 -- 1 = churnou, 0 = permaneceu
  InternetService,
  CASE WHEN OnlineSecurity   = 'Yes' THEN 1 ELSE 0 END AS f_Security,
  CASE WHEN OnlineBackup     = 'Yes' THEN 1 ELSE 0 END AS f_Backup,
  CASE WHEN DeviceProtection = 'Yes' THEN 1 ELSE 0 END AS f_Protection,
  CASE WHEN TechSupport      = 'Yes' THEN 1 ELSE 0 END AS f_Support,
  CASE WHEN StreamingTV      = 'Yes' THEN 1 ELSE 0 END AS f_TV,
  CASE WHEN StreamingMovies  = 'Yes' THEN 1 ELSE 0 END AS f_Movies
FROM telco_clean;
```
Podemos fazer essa analise de duas formas, uma com diversas queries separadas e analisar cada, ou fazer apenas uma query montando uma tabela geral com uma análise mais focada.
Decidi seguir com apenas uma query, assim conseguimos visualizar melhor o que cada dado representa.

## Query utilizada no MySQL

```sql
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
```

Com essa query mais estensa colocamos filtros diferentes usando o CASE WHEN para filtrar dados onde a função esta positiva (1), e quando esta negativa (0).

<p align="center">
  <img src="docs/customer_churn_internetandadd.png" alt="Contagem de clientes Olist" style="max-width:80%;">
</p>

A análise mostra que o tipo de serviço de internet e os add-ons contratados têm impacto direto nas taxas de churn:

- InternetService
  - Clientes com Fiber optic tendem a ter churn mais alto, possivelmente por causa de preço ou perfil mais sensível a custos.
  - Clientes com DSL apresentam churn menor em comparação.
  - Quem não possui serviço de internet geralmente apresenta churn ainda mais baixo, mas também têm ticket médio reduzido.

- Add-ons de Segurança e Suporte
  - OnlineSecurity e TechSupport estão associados a forte redução no churn (uplift negativo de até ~16 pontos percentuais).  
  - Isso sugere que clientes que contam com proteção e suporte percebem mais valor e permanecem mais tempo.

- Add-ons de Backup e Proteção
  - OnlineBackup e DeviceProtection também reduzem o churn, mas em menor escala (cerca de −6 a −8 pp).  
  - Ainda assim, contribuem para a fidelização.

- Add-ons de Entretenimento
  - StreamingTV e StreamingMovies estão associados a maior churn (uplift positivo de ~+6 pp).  
  - Isso pode indicar que usuários que contratam apenas entretenimento são mais sensíveis a preço ou estão em planos de contrato mensal, mais fáceis de cancelar.

### Interpretação
- Add-ons de segurança e suporte funcionam como fatores de retenção, fortalecendo o vínculo do cliente.  
- Add-ons de entretenimento aumentam o risco de saída, exigindo estratégias específicas (como bundles com segurança ou descontos em contratos anuais).  
- O uplift mede essa diferença: se negativo, o recurso ajuda a reduzir churn; se positivo, aumenta o risco.  








