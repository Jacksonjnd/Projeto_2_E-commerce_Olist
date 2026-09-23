-- =====================================================
-- PROJETO OLIST E-COMMERCE
-- 03. VALIDAÇÃO DE FOREIGN KEYS
-- =====================================================
/*
Objetivo:
Validar os relacionamentos entre as tabelas
e identificar possíveis registros órfãos.
*/


-- =====================================================
-- 3.1 ORDERS x CUSTOMERS
-- Verificar se existem customer_id órfãos em orders
-- =====================================================
SELECT COUNT(*) AS registros_orfaos
FROM staging.olist_orders_dataset
LEFT JOIN staging.olist_customers_dataset
ON olist_orders_dataset.customer_id = olist_customers_dataset.customer_id
WHERE olist_customers_dataset.customer_id IS NULL;


-- Conclusão:
-- Não existem registros órfãos entre orders e customers.
-- Todo customer_id presente em orders possui correspondência em customers.
-- Portanto, o relacionamento é válido como candidato a Foreign Key.

-- =====================================================
-- 3.2 ORDER ITEMS x ORDERS
-- Verificar se existem order_id órfãos em order_items
-- =====================================================
SELECT COUNT(*) AS registros_orfaos
FROM staging.olist_order_items_dataset
LEFT JOIN staging.olist_orders_dataset
ON olist_order_items_dataset.order_id = olist_orders_dataset.order_id
WHERE olist_orders_dataset.order_id IS NULL;


-- Conclusão:
-- Não existem registros órfãos entre order_items e orders.
-- Todo order_id presente em order_items possui correspondência em orders.
-- Portanto, o relacionamento é válido como candidato a Foreign Key.


-- =====================================================
-- 3.3 ORDER ITEMS x PRODUCTS
-- Verificar se existem product_id órfãos em order_items
-- =====================================================
SELECT COUNT(*) AS registros_orfaos
FROM staging.olist_order_items_dataset
LEFT JOIN staging.olist_products_dataset
ON olist_order_items_dataset.product_id = olist_products_dataset.product_id
WHERE olist_products_dataset.product_id IS NULL;

-- Conclusão:
-- Não existem registros órfãos entre order_items e products.
-- Todo product_id presente em order_items possui correspondência em products.
-- Portanto, o relacionamento é válido como candidato a Foreign Key.

-- =====================================================
-- 3.4 ORDER ITEMS x SELLERS
-- Verificar se existem seller_id órfãos em order_items
-- =====================================================
SELECT COUNT(*) AS registros_orfaos
FROM staging.olist_order_items_dataset
LEFT JOIN staging.olist_sellers_dataset
ON olist_order_items_dataset.seller_id = olist_sellers_dataset.seller_id
WHERE olist_sellers_dataset.seller_id IS NULL;

-- Conclusão:
-- Não existem registros órfãos entre order_items e sellers.
-- Todo seller_id presente em order_items possui correspondência em sellers.
-- Portanto, o relacionamento é válido como candidato a Foreign Key.


-- =====================================================
-- 3.5 ORDER PAYMENTS x ORDERS
-- Verificar se existem order_id órfãos em order_payments
-- =====================================================
SELECT COUNT(*) AS registros_orfaos
FROM staging.olist_order_payments_dataset
LEFT JOIN staging.olist_orders_dataset
ON olist_order_payments_dataset.order_id = olist_orders_dataset.order_id
WHERE olist_orders_dataset.order_id IS NULL;

-- Conclusão:
-- Não existem registros órfãos entre order_payments e orders.
-- Todo order_id presente em order_payments possui correspondência em orders.
-- Portanto, o relacionamento é válido como candidato a Foreign Key.


-- =====================================================
-- 3.6 ORDER REVIEWS x ORDERS
-- Verificar se existem order_id órfãos em order_reviews
-- =====================================================
SELECT COUNT(*) AS registros_orfaos
FROM staging.olist_order_reviews_dataset
LEFT JOIN staging.olist_orders_dataset
ON olist_order_reviews_dataset.order_id = olist_orders_dataset.order_id
WHERE olist_orders_dataset.order_id IS NULL;


-- Conclusão:
-- Não existem registros órfãos entre order_reviews e orders.
-- Todo order_id presente em order_reviews possui correspondência em orders.
-- Portanto, o relacionamento é válido como candidato a Foreign Key.


-- =====================================================
-- 3.7 PRODUCTS x CATEGORY TRANSLATION
-- Verificar categorias sem correspondência na tradução
-- =====================================================
SELECT COUNT(*) AS registros_orfaos
FROM staging.olist_products_dataset
LEFT JOIN staging.product_category_name_translation
ON olist_products_dataset.product_category_name = product_category_name_translation.product_category_name
WHERE olist_products_dataset.product_category_name IS NOT NULL
AND product_category_name_translation.product_category_name IS NULL;


-- Conclusão:
-- A validação retornou 623 registros sem correspondência na tabela de tradução.
-- O resultado indica que existem produtos cuja categoria não encontrou correspondência
-- em product_category_name_translation.
-- Como a condição IS NOT NULL também considera strings vazias como valores preenchidos,
-- será necessário refinar a validação para separar categorias realmente informadas
-- de registros com campo vazio.

-- =====================================================
-- 3.7.1 AJUSTE DA VALIDAÇÃO
-- Desconsiderar strings vazias em product_category_name
-- =====================================================

SELECT COUNT(*) AS registros_orfaos
FROM staging.olist_products_dataset
LEFT JOIN staging.product_category_name_translation
ON olist_products_dataset.product_category_name = product_category_name_translation.product_category_name
WHERE NULLIF(TRIM(olist_products_dataset.product_category_name), '') IS NOT NULL
AND product_category_name_translation.product_category_name IS NULL;

-- Conclusão:
-- Após desconsiderar strings vazias, foram identificados 13 produtos
-- com product_category_name preenchido, mas sem correspondência
-- em product_category_name_translation.
-- Portanto, o relacionamento ainda apresenta inconsistências
-- e não está totalmente íntegro para criação direta de uma Foreign Key.

-- =====================================================
-- 3.7.2 IDENTIFICAR CATEGORIAS SEM TRADUÇÃO
-- Verificar quais categorias não possuem correspondência
-- =====================================================
SELECT olist_products_dataset.product_category_name, COUNT(*) AS total_produtos
FROM staging.olist_products_dataset
LEFT JOIN staging.product_category_name_translation
ON olist_products_dataset.product_category_name = product_category_name_translation.product_category_name
WHERE NULLIF(TRIM(olist_products_dataset.product_category_name), '') IS NOT NULL
AND product_category_name_translation.product_category_name IS NULL
GROUP BY olist_products_dataset.product_category_name
ORDER BY total_produtos DESC;

-- Conclusão:
-- Foram identificadas 2 categorias sem correspondência
-- na tabela product_category_name_translation:
-- portateis_cozinha_e_preparadores_de_alimentos → 10 produtos
-- pc_gamer                                      → 3 produtos
-- Total: 13 produtos sem tradução correspondente.
-- Portanto, o relacionamento products x category_translation
-- apresenta uma inconsistência de integridade referencial que irei
-- tratar na etapa de qualidade/modelagem dos dados.


-- =====================================================
-- 3.8 CUSTOMERS x GEOLOCATION
-- Verificar CEPs de clientes sem correspondência em geolocation
-- =====================================================
SELECT COUNT(*) AS clientes_sem_geolocalizacao,
COUNT(DISTINCT olist_customers_dataset.customer_zip_code_prefix) AS ceps_sem_correspondencia
FROM staging.olist_customers_dataset
LEFT JOIN (SELECT DISTINCT geolocation_zip_code_prefix FROM staging.olist_geolocation_dataset) AS geolocation_distinta
ON olist_customers_dataset.customer_zip_code_prefix = geolocation_distinta.geolocation_zip_code_prefix
WHERE geolocation_distinta.geolocation_zip_code_prefix IS NULL;


-- Conclusão:
-- Foram identificados 278 clientes com CEP sem correspondência
-- na tabela geolocation, distribuídos em 157 CEPs distintos.
-- Portanto, a cobertura geográfica não é completa para todos os clientes.
-- Além disso, geolocation_zip_code_prefix não é único em geolocation,
-- portanto essa relação não pode ser tratada diretamente como Foreign Key
-- no estado atual da camada staging.


-- =====================================================
-- 3.9 SELLERS x GEOLOCATION
-- Verificar CEPs de vendedores sem correspondência em geolocation
-- =====================================================
SELECT COUNT(*) AS sellers_sem_geolocalizacao,
COUNT(DISTINCT olist_sellers_dataset.seller_zip_code_prefix) AS ceps_sem_correspondencia
FROM staging.olist_sellers_dataset
LEFT JOIN (SELECT DISTINCT geolocation_zip_code_prefix FROM staging.olist_geolocation_dataset) AS geolocation_distinta
ON olist_sellers_dataset.seller_zip_code_prefix = geolocation_distinta.geolocation_zip_code_prefix
WHERE geolocation_distinta.geolocation_zip_code_prefix IS NULL;

-- Conclusão:
-- Foram identificados 7 vendedores com CEP sem correspondência
-- na tabela geolocation, distribuídos em 7 CEPs distintos.
-- Portanto, a cobertura geográfica também não é completa para todos os sellers.
-- Além disso, geolocation_zip_code_prefix não é único em geolocation,
-- portanto essa relação não pode ser tratada diretamente como Foreign Key
-- no estado atual da camada staging.


-- =====================================================
-- RESUMO DA VALIDAÇÃO DE FOREIGN KEYS - ANOTAÇÕES
-- =====================================================
-- orders.customer_id → customers.customer_id
-- Resultado: válido, sem registros órfãos.
--
-- order_items.order_id → orders.order_id
-- Resultado: válido, sem registros órfãos.
--
-- order_items.product_id → products.product_id
-- Resultado: válido, sem registros órfãos.
--
-- order_items.seller_id → sellers.seller_id
-- Resultado: válido, sem registros órfãos.
--
-- order_payments.order_id → orders.order_id
-- Resultado: válido, sem registros órfãos.
--
-- order_reviews.order_id → orders.order_id
-- Resultado: válido, sem registros órfãos.
--
-- products.product_category_name → product_category_translation.product_category_name
-- Resultado: 13 produtos sem correspondência, distribuídos em 2 categorias.
-- O relacionamento precisa de tratamento antes da criação da Foreign Key.
--
-- customers.customer_zip_code_prefix → geolocation.geolocation_zip_code_prefix
-- Resultado: 278 clientes e 157 CEPs sem correspondência.
-- geolocation_zip_code_prefix não é único, portanto não pode ser FK direta.
--
-- sellers.seller_zip_code_prefix → geolocation.geolocation_zip_code_prefix
-- Resultado: 7 sellers e 7 CEPs sem correspondência.
-- geolocation_zip_code_prefix não é único, portanto não pode ser FK direta.





















