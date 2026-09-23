-- =====================================================
-- PROJETO OLIST E-COMMERCE
-- 02. VALIDAÇÃO DE PRIMARY KEYS
-- =====================================================

/*
Objetivo:
Identificar as colunas candidatas a chave primária
nas tabelas do modelo relacional.

Critérios para uma Primary Key:
1. Não possuir valores duplicados.
2. Não possuir valores nulos.
3. Identificar unicamente cada registro.
*/

-- =====================================================
-- 2.1 CUSTOMERS
-- Verificar se customer_id pode ser utilizado como PK
-- =====================================================

SELECT
    COUNT(*) AS total_linhas,
    COUNT(customer_id) AS valores_nao_nulos,
    COUNT(DISTINCT customer_id) AS valores_unicos
FROM staging.olist_customers_dataset;


-- Conclusão:
-- customer_id possui 99.441 valores não nulos e 99.441 valores únicos.
-- Portanto, atende aos critérios técnicos para ser utilizado como Primary Key.

-- =====================================================
-- 2.2 ORDERS
-- Verificar se order_id pode ser utilizado como PK
-- =====================================================

SELECT
    COUNT(*) AS total_linhas,
    COUNT(order_id) AS valores_nao_nulos,
    COUNT(DISTINCT order_id) AS valores_unicos
FROM staging.olist_orders_dataset;


-- =====================================================
-- 2.3 PRODUCTS
-- Verificar se product_id pode ser utilizado como PK
-- =====================================================

SELECT
    COUNT(*) AS total_linhas,
    COUNT(product_id) AS valores_nao_nulos,
    COUNT(DISTINCT product_id) AS valores_unicos
FROM staging.olist_products_dataset;


-- Conclusão:
-- product_id possui 32.951 valores não nulos e 32.951 valores únicos.
-- Portanto, atende aos critérios técnicos para ser utilizado como Primary Key.

-- =====================================================
-- 2.4 SELLERS
-- Verificar se seller_id pode ser utilizado como PK
-- =====================================================

SELECT
    COUNT(*) AS total_linhas,
    COUNT(seller_id) AS valores_nao_nulos,
    COUNT(DISTINCT seller_id) AS valores_unicos
FROM staging.olist_sellers_dataset;


-- Conclusão:
-- seller_id possui 3.095 valores não nulos e 3.095 valores únicos.
-- Portanto, atende aos critérios técnicos para ser utilizado como Primary Key.

-- =====================================================
-- 2.5 ORDER ITEMS
-- Verificar a necessidade de uma chave primária composta
-- =====================================================

SELECT
    COUNT(*) AS total_linhas,
    COUNT(order_id) AS order_id_nao_nulos,
    COUNT(DISTINCT order_id) AS order_ids_unicos,
    COUNT(order_item_id) AS order_item_id_nao_nulos,
    COUNT(
        DISTINCT (order_id, order_item_id)
    ) AS combinacoes_unicas
FROM staging.olist_order_items_dataset;

-- Conclusão:
-- order_id sozinho não pode ser utilizado como Primary Key, pois se repete.
-- A combinação order_id + order_item_id possui 112.650 valores não nulos
-- e 112.650 combinações únicas.
-- Portanto, atende aos critérios para uma Primary Key composta.

-- =====================================================
-- 2.6 PAYMENTS
-- Verificar a necessidade de uma chave primária composta
-- =====================================================
SELECT
    COUNT(*) AS total_linhas,
    COUNT(order_id) AS order_id_nao_nulos,
    COUNT(DISTINCT order_id) AS order_ids_unicos,
    COUNT(payment_sequential) AS payment_sequential_nao_nulos,
    COUNT(DISTINCT (order_id, payment_sequential)) AS combinacoes_unicas
FROM staging.olist_order_payments_dataset;


-- Conclusão:
-- order_id sozinho não pode ser utilizado como Primary Key, pois se repete.
-- A combinação order_id + payment_sequential possui 103.886 combinações únicas.
-- Portanto, atende aos critérios para uma Primary Key composta.

-- =====================================================
-- 2.7 REVIEWS
-- Verificar a necessidade de uma chave primária composta
-- =====================================================
SELECT
    COUNT(*) AS total_linhas,
    COUNT(review_id) AS review_id_nao_nulos,
    COUNT(DISTINCT review_id) AS review_ids_unicos,
    COUNT(order_id) AS order_id_nao_nulos,
    COUNT(DISTINCT (review_id, order_id)) AS combinacoes_unicas
FROM staging.olist_order_reviews_dataset;


-- Conclusão:
-- review_id sozinho não pode ser utilizado como Primary Key, pois se repete.
-- A combinação review_id + order_id possui 99.224 combinações únicas.
-- Portanto, atende aos critérios para uma Primary Key composta.


-- =====================================================
-- 2.8 PRODUCT CATEGORY TRANSLATION
-- Verificar se product_category_name pode ser utilizado como PK
-- =====================================================
SELECT
    COUNT(*) AS total_linhas,
    COUNT(product_category_name) AS valores_nao_nulos,
    COUNT(DISTINCT product_category_name) AS valores_unicos
FROM staging.product_category_name_translation;


-- Conclusão:
-- product_category_name possui 71 valores não nulos e 71 valores únicos.
-- Portanto, atende aos critérios técnicos para ser utilizado como Primary Key.


-- =====================================================
-- 2.9 GEOLOCATION
-- Investigar possíveis candidatos a Primary Key
-- =====================================================
SELECT
    COUNT(*) AS total_linhas,
    COUNT(geolocation_zip_code_prefix) AS cep_nao_nulos,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS ceps_unicos
FROM staging.olist_geolocation_dataset;

-- Verificar se existem linhas totalmente duplicadas na tabela geolocation
SELECT
    COUNT(*) AS total_linhas,
    COUNT(DISTINCT (
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    )) AS combinacoes_unicas
FROM staging.olist_geolocation_dataset;

-- Conclusão:
-- geolocation_zip_code_prefix não pode ser utilizado como Primary Key,
-- pois existem apenas 19.015 CEPs distintos em 1.000.163 registros.
-- Mesmo considerando todas as colunas em conjunto, existem apenas
-- 738.332 combinações únicas.
-- Portanto, a tabela possui registros totalmente duplicados e não apresenta
-- uma chave primária natural adequada no estado atual.
-- A definição da chave será tratada após a limpeza e modelagem dos dados.


-- =====================================================
-- RESUMO DAS CHAVES PRIMÁRIAS CANDIDATAS
-- =====================================================
-- customers                    → customer_id
-- orders                       → order_id
-- products                     → product_id
-- sellers                      → seller_id
-- order_items                  → order_id + order_item_id
-- order_payments               → order_id + payment_sequential
-- order_reviews                → review_id + order_id
-- product_category_translation → product_category_name
-- geolocation                  → sem Primary Key natural adequada no staging

