-- =====================================================
-- PROJETO OLIST E-COMMERCE
-- 05. MODELAGEM RELACIONAL
-- =====================================================

/*
Anotações - reflexões - espaço para desenhar a modelagem que irei fazer:
Construir o modelo relacional do projeto a partir dos dados
validados na camada staging.

Nesta etapa irei definir:
- tabelas da camada modelada;
- granularidade de cada tabela;
- Primary Keys;
- Foreign Keys;
- chaves compostas;
- relacionamentos;
- tratamentos necessários antes da carga definitiva.

A camada staging será preservada sem alterações.
*/

-- =====================================================
-- 5.1 DESENHO LÓGICO DO MODELO
-- =====================================================

/*
1. customers
   Granularidade: um registro por customer_id.
   Primary Key: customer_id.
   customer_unique_id identifica o cliente real e pode aparecer
   em mais de um customer_id.

2. orders
   Granularidade: um registro por pedido.
   Primary Key: order_id.
   Foreign Key: customer_id -> customers.customer_id.

3. products
   Granularidade: um registro por produto.
   Primary Key: product_id.
   product_category_name poderá se relacionar com
   product_category_translation após tratamento das categorias
   sem correspondência.

4. sellers
   Granularidade: um registro por vendedor.
   Primary Key: seller_id.

5. order_items
   Granularidade: um registro por item dentro de um pedido.
   Primary Key composta: order_id + order_item_id.
   Foreign Keys:
   order_id -> orders.order_id
   product_id -> products.product_id
   seller_id -> sellers.seller_id.

6. order_payments
   Granularidade: um registro por sequência de pagamento do pedido.
   Primary Key composta: order_id + payment_sequential.
   Foreign Key: order_id -> orders.order_id.

7. order_reviews
   Granularidade: um registro por avaliação associada ao pedido.
   Primary Key composta: review_id + order_id.
   Foreign Key: order_id -> orders.order_id.
   Um pedido pode possuir mais de uma avaliação.

8. product_category_translation
   Granularidade: uma linha por categoria.
   Primary Key: product_category_name.
   Possui a tradução da categoria para inglês.

9. geolocation
   Granularidade: uma combinação geográfica.
   Não possui Primary Key natural adequada no staging.
   Será criada uma chave artificial na camada modelada.
   Registros exatamente duplicados serão removidos.
   geolocation_zip_code_prefix continuará podendo aparecer
   mais de uma vez e não será tratado como chave única.
*/


-- =====================================================
-- 5.1.1 RELACIONAMENTOS
-- =====================================================

/*
customers 1 ---- N orders

orders 1 ---- N order_items
orders 1 ---- N order_payments
orders 1 ---- N order_reviews

products 1 ---- N order_items

sellers 1 ---- N order_items

product_category_translation 1 ---- N products
(relacionamento sujeito ao tratamento das categorias sem tradução)

geolocation:
não será criada Foreign Key direta com customers ou sellers,
pois geolocation_zip_code_prefix não é único na tabela geolocation.
*/



-- =====================================================
-- 5.2 CRIAÇÃO DA CAMADA MODELADA
-- Criar schema destinado às tabelas tratadas e relacionais
-- =====================================================

CREATE SCHEMA modelado;

-- O schema modelado foi criado para armazenar as tabelas
-- relacionais e tratadas do projeto.
-- A camada staging será preservada como fonte original dos dados.

-- =====================================================
-- 5.3.1 CUSTOMERS - CRIAÇÃO E CARGA
-- =====================================================

CREATE TABLE modelado.customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50) NOT NULL,
    customer_zip_code_prefix VARCHAR(5) NOT NULL,
    customer_city VARCHAR(50) NOT NULL,
    customer_state CHAR(2) NOT NULL
);

INSERT INTO modelado.customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    TRIM(customer_city),
    UPPER(TRIM(customer_state))
FROM staging.olist_customers_dataset;

-- Validação
SELECT COUNT(*) AS total_registros
FROM modelado.customers;


-- =====================================================
-- 5.3.2 PRODUCT CATEGORY TRANSLATION - CRIAÇÃO E CARGA
-- =====================================================

CREATE TABLE modelado.product_category_translation (
    product_category_name VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100) NOT NULL
);

INSERT INTO modelado.product_category_translation (
    product_category_name,
    product_category_name_english
)
SELECT
    TRIM(product_category_name),
    TRIM(product_category_name_english)
FROM staging.product_category_name_translation;

-- Validação
SELECT COUNT(*) AS total_registros
FROM modelado.product_category_translation;


-- =====================================================
-- 5.3.2.1 PRODUCT CATEGORY - CATEGORIAS SEM TRADUÇÃO
-- =====================================================
ALTER TABLE modelado.product_category_translation
ALTER COLUMN product_category_name_english DROP NOT NULL;

INSERT INTO modelado.product_category_translation (product_category_name,product_category_name_english)
VALUES
('portateis_cozinha_e_preparadores_de_alimentos',NULL),
('pc_gamer',NULL)
ON CONFLICT (product_category_name) DO NOTHING;

SELECT COUNT(*) AS total_categorias
FROM modelado.product_category_translation;


-- =====================================================
-- 5.3.3 PRODUCTS - CRIAÇÃO E CARGA
-- =====================================================
CREATE TABLE modelado.products (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photos_qty INTEGER,
    product_weight_g NUMERIC(10,2),
    product_length_cm NUMERIC(10,2),
    product_height_cm NUMERIC(10,2),
    product_width_cm NUMERIC(10,2),
    CONSTRAINT fk_products_category FOREIGN KEY (product_category_name) REFERENCES modelado.product_category_translation(product_category_name)
);
INSERT INTO modelado.products (product_id,product_category_name,product_name_length,product_description_length,product_photos_qty,product_weight_g,product_length_cm,product_height_cm,product_width_cm)
SELECT product_id,NULLIF(TRIM(product_category_name),''),product_name_lenght::INTEGER,product_description_lenght::INTEGER,product_photos_qty::INTEGER,product_weight_g::NUMERIC(10,2),product_length_cm::NUMERIC(10,2),product_height_cm::NUMERIC(10,2),product_width_cm::NUMERIC(10,2)
FROM staging.olist_products_dataset;
SELECT COUNT(*) AS total_produtos
FROM modelado.products;


-- =====================================================
-- 5.3.4 SELLERS - CRIAÇÃO E CARGA
-- =====================================================
CREATE TABLE modelado.sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(5) NOT NULL,
    seller_city VARCHAR(50) NOT NULL,
    seller_state CHAR(2) NOT NULL
);
INSERT INTO modelado.sellers (seller_id,seller_zip_code_prefix,seller_city,seller_state)
SELECT seller_id,seller_zip_code_prefix,TRIM(seller_city),UPPER(TRIM(seller_state))
FROM staging.olist_sellers_dataset;
SELECT COUNT(*) AS total_sellers
FROM modelado.sellers;

-- =====================================================
-- 5.3.5 ORDERS - CRIAÇÃO E CARGA
-- =====================================================
CREATE TABLE modelado.orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    order_status VARCHAR(30) NOT NULL,
    order_purchase_timestamp TIMESTAMP NOT NULL,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP NOT NULL,
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES modelado.customers(customer_id)
);
INSERT INTO modelado.orders (order_id,customer_id,order_status,order_purchase_timestamp,order_approved_at,order_delivered_carrier_date,order_delivered_customer_date,order_estimated_delivery_date)
SELECT order_id,customer_id,LOWER(TRIM(order_status)),order_purchase_timestamp::TIMESTAMP,order_approved_at::TIMESTAMP,order_delivered_carrier_date::TIMESTAMP,order_delivered_customer_date::TIMESTAMP,order_estimated_delivery_date::TIMESTAMP
FROM staging.olist_orders_dataset;
SELECT COUNT(*) AS total_orders
FROM modelado.orders;

-- =====================================================
-- 5.3.6 ORDER_ITEMS - CRIAÇÃO E CARGA
-- =====================================================
CREATE TABLE modelado.order_items (
    order_id VARCHAR(50) NOT NULL,
    order_item_id INTEGER NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    seller_id VARCHAR(50) NOT NULL,
    shipping_limit_date TIMESTAMP NOT NULL,
    price NUMERIC(10,2) NOT NULL,
    freight_value NUMERIC(10,2) NOT NULL,
    CONSTRAINT pk_order_items PRIMARY KEY (order_id,order_item_id),
    CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES modelado.orders(order_id),
    CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES modelado.products(product_id),
    CONSTRAINT fk_order_items_seller FOREIGN KEY (seller_id) REFERENCES modelado.sellers(seller_id)
);
INSERT INTO modelado.order_items (order_id,order_item_id,product_id,seller_id,shipping_limit_date,price,freight_value)
SELECT order_id,order_item_id::INTEGER,product_id,seller_id,shipping_limit_date::TIMESTAMP,price::NUMERIC(10,2),freight_value::NUMERIC(10,2)
FROM staging.olist_order_items_dataset;
SELECT COUNT(*) AS total_order_items
FROM modelado.order_items;


-- =====================================================
-- 5.3.7 ORDER_PAYMENTS - CRIAÇÃO E CARGA
-- =====================================================
CREATE TABLE modelado.order_payments (
    order_id VARCHAR(50) NOT NULL,
    payment_sequential INTEGER NOT NULL,
    payment_type VARCHAR(30) NOT NULL,
    payment_installments INTEGER NOT NULL,
    payment_value NUMERIC(10,2) NOT NULL,
    CONSTRAINT pk_order_payments PRIMARY KEY (order_id,payment_sequential),
    CONSTRAINT fk_order_payments_order FOREIGN KEY (order_id) REFERENCES modelado.orders(order_id)
);
INSERT INTO modelado.order_payments (order_id,payment_sequential,payment_type,payment_installments,payment_value)
SELECT order_id,payment_sequential::INTEGER,LOWER(TRIM(payment_type)),payment_installments::INTEGER,payment_value::NUMERIC(10,2)
FROM staging.olist_order_payments_dataset;
SELECT COUNT(*) AS total_order_payments
FROM modelado.order_payments;


-- =====================================================
-- 5.3.8 ORDER_REVIEWS - CRIAÇÃO E CARGA
-- =====================================================
CREATE TABLE modelado.order_reviews (
    review_id VARCHAR(50) NOT NULL,
    order_id VARCHAR(50) NOT NULL,
    review_score INTEGER NOT NULL,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP NOT NULL,
    review_answer_timestamp TIMESTAMP NOT NULL,
    CONSTRAINT pk_order_reviews PRIMARY KEY (review_id,order_id),
    CONSTRAINT fk_order_reviews_order FOREIGN KEY (order_id) REFERENCES modelado.orders(order_id)
);
INSERT INTO modelado.order_reviews (review_id,order_id,review_score,review_comment_title,review_comment_message,review_creation_date,review_answer_timestamp)
SELECT review_id,order_id,review_score::INTEGER,NULLIF(TRIM(review_comment_title),''),NULLIF(TRIM(review_comment_message),''),review_creation_date::TIMESTAMP,review_answer_timestamp::TIMESTAMP
FROM staging.olist_order_reviews_dataset;
SELECT COUNT(*) AS total_order_reviews
FROM modelado.order_reviews;


-- =====================================================
-- 5.3.9 GEOLOCATION - CRIAÇÃO E CARGA
-- =====================================================
CREATE TABLE modelado.geolocation (
    geolocation_id BIGSERIAL PRIMARY KEY,
    geolocation_zip_code_prefix VARCHAR(5) NOT NULL,
    geolocation_lat NUMERIC(12,8) NOT NULL,
    geolocation_lng NUMERIC(12,8) NOT NULL,
    geolocation_city VARCHAR(100) NOT NULL,
    geolocation_state CHAR(2) NOT NULL
);
INSERT INTO modelado.geolocation (geolocation_zip_code_prefix,geolocation_lat,geolocation_lng,geolocation_city,geolocation_state)
SELECT DISTINCT geolocation_zip_code_prefix,geolocation_lat::NUMERIC(12,8),geolocation_lng::NUMERIC(12,8),TRIM(geolocation_city),UPPER(TRIM(geolocation_state))
FROM staging.olist_geolocation_dataset;
SELECT COUNT(*) AS total_geolocation
FROM modelado.geolocation;


-- =====================================================
-- 5.4.1 VALIDAÇÃO DAS QUANTIDADES
-- =====================================================
SELECT 'customers' AS tabela,COUNT(*) AS total_registros FROM modelado.customers
UNION ALL
SELECT 'orders',COUNT(*) FROM modelado.orders
UNION ALL
SELECT 'products',COUNT(*) FROM modelado.products
UNION ALL
SELECT 'sellers',COUNT(*) FROM modelado.sellers
UNION ALL
SELECT 'order_items',COUNT(*) FROM modelado.order_items
UNION ALL
SELECT 'order_payments',COUNT(*) FROM modelado.order_payments
UNION ALL
SELECT 'order_reviews',COUNT(*) FROM modelado.order_reviews
UNION ALL
SELECT 'product_category_translation',COUNT(*) FROM modelado.product_category_translation
UNION ALL
SELECT 'geolocation',COUNT(*) FROM modelado.geolocation
ORDER BY tabela;


-- =====================================================
-- 5.4.2 VALIDAÇÃO DAS CONSTRAINTS
-- =====================================================
SELECT table_name,constraint_name,constraint_type
FROM information_schema.table_constraints
WHERE table_schema='modelado'
AND constraint_type IN ('PRIMARY KEY','FOREIGN KEY')
ORDER BY table_name,constraint_type,constraint_name;


-- Conclusão:
-- As tabelas da camada modelada foram carregadas com sucesso.
-- As quantidades foram preservadas nas tabelas em que não houve
-- tratamento de registros.
-- A tabela product_category_translation foi ampliada para contemplar
-- categorias existentes em products sem tradução correspondente.
-- A tabela geolocation foi deduplicada conforme definido na modelagem.
-- Primary Keys e Foreign Keys foram implementadas para garantir
-- integridade estrutural e referencial do modelo.



-- =====================================================
-- 5.4.1.1 GEOLOCATION - VALIDAÇÃO DA DEDUPLICAÇÃO
-- =====================================================
SELECT COUNT(*) AS total_combinacoes_tratadas
FROM (
SELECT DISTINCT geolocation_zip_code_prefix,geolocation_lat::NUMERIC(12,8),geolocation_lng::NUMERIC(12,8),
TRIM(geolocation_city),UPPER(TRIM(geolocation_state))
FROM staging.olist_geolocation_dataset
) AS geolocation_tratada;


-- =====================================================
-- CONCLUSÃO DA FASE 05 - MODELAGEM RELACIONAL
-- =====================================================
-- A camada modelada foi criada e carregada com sucesso.
-- As tabelas mantiveram as quantidades esperadas após os tratamentos definidos.
-- product_category_translation passou de 71 para 73 registros para contemplar
-- categorias existentes em products que não possuíam tradução.
-- geolocation foi reduzida de 1.000.163 para 738.327 registros após
-- deduplicação e padronização das coordenadas, cidade e estado.
-- A diferença entre as 738.332 combinações originalmente distintas
-- e as 738.327 combinações tratadas ocorreu após a padronização aplicada.
-- Todas as tabelas possuem Primary Keys e as Foreign Keys previstas
-- foram implementadas com sucesso.
-- A camada modelada está pronta para utilização nas análises.








