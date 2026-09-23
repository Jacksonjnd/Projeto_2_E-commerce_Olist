-- =====================================================
-- PROJETO OLIST E-COMMERCE
-- 01. VALIDAÇÃO DA CAMADA STAGING
-- =====================================================

/*
Objetivo:
Validar se os 9 arquivos CSV foram carregados
corretamente no schema staging.

A validação compara a quantidade de registros
importados em cada tabela.
*/

SELECT 'olist_customers_dataset' AS tabela, COUNT(*) AS total_linhas
FROM staging.olist_customers_dataset
UNION ALL
SELECT 'olist_geolocation_dataset', COUNT(*)
FROM staging.olist_geolocation_dataset
UNION ALL
SELECT 'olist_order_items_dataset', COUNT(*)
FROM staging.olist_order_items_dataset
UNION ALL
SELECT 'olist_order_payments_dataset', COUNT(*)
FROM staging.olist_order_payments_dataset
UNION ALL
SELECT 'olist_order_reviews_dataset', COUNT(*)
FROM staging.olist_order_reviews_dataset
UNION ALL
SELECT 'olist_orders_dataset', COUNT(*)
FROM staging.olist_orders_dataset
UNION ALL
SELECT 'olist_products_dataset', COUNT(*)
FROM staging.olist_products_dataset
UNION ALL
SELECT 'olist_sellers_dataset', COUNT(*)
FROM staging.olist_sellers_dataset
UNION ALL
SELECT 'product_category_name_translation', COUNT(*)
FROM staging.product_category_name_translation
ORDER BY tabela;