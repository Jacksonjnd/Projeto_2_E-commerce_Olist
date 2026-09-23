-- =====================================================
-- PROJETO OLIST E-COMMERCE
-- 06. CAMADAS ANALÍTICAS
-- =====================================================
/*
Objetivo:
Criar views analíticas reutilizáveis para consumo no Python
e no dashboard, preservando a camada modelada como fonte relacional.

Princípios:
- manter uma granularidade clara em cada view;
- evitar multiplicação de registros em JOINs;
- consolidar pagamentos e avaliações antes de uni-los aos pedidos;
- preparar métricas e variáveis analíticas sem substituir a EDA em Python;
- preservar todos os pedidos, inclusive cancelados e indisponíveis.

Regra analítica:
pedido_valido = order_status diferente de 'canceled' e 'unavailable'.

Estrutura:
6.1  vw_orders_base
6.2  vw_order_items_base
6.3  vw_payments_order
6.4  vw_reviews_order
6.5  vw_orders_analytics
6.6  vw_customers_analytics
6.7  vw_products_analytics
6.8  vw_sellers_analytics
6.9  vw_categories_analytics
6.10 vw_geolocation_zip
6.11 dim_calendar
*/

-- =====================================================
-- 6.1 VW_ORDERS_BASE
-- Granularidade: 1 linha por pedido
-- Objetivo: reunir pedido, cliente e indicadores logísticos
-- =====================================================
CREATE OR REPLACE VIEW modelado.vw_orders_base AS
SELECT
    orders.order_id,
    orders.customer_id,
    customers.customer_unique_id,
    orders.order_status,
    (orders.order_status NOT IN ('canceled','unavailable')) AS pedido_valido,
    orders.order_purchase_timestamp,
    orders.order_approved_at,
    orders.order_delivered_carrier_date,
    orders.order_delivered_customer_date,
    orders.order_estimated_delivery_date,
    customers.customer_zip_code_prefix,
    customers.customer_city,
    customers.customer_state,
    CASE WHEN orders.order_delivered_customer_date IS NOT NULL THEN ROUND((EXTRACT(EPOCH FROM (orders.order_delivered_customer_date-orders.order_purchase_timestamp))/86400)::NUMERIC,2) END AS dias_para_entrega,
    CASE WHEN orders.order_delivered_customer_date IS NOT NULL THEN ROUND((EXTRACT(EPOCH FROM (orders.order_delivered_customer_date-orders.order_estimated_delivery_date))/86400)::NUMERIC,2) END AS diferenca_prazo_dias,
    CASE WHEN orders.order_delivered_customer_date IS NOT NULL THEN GREATEST(ROUND((EXTRACT(EPOCH FROM (orders.order_delivered_customer_date-orders.order_estimated_delivery_date))/86400)::NUMERIC,2),0::NUMERIC) END AS dias_atraso,
    CASE WHEN orders.order_delivered_customer_date IS NULL THEN NULL WHEN orders.order_delivered_customer_date<=orders.order_estimated_delivery_date THEN TRUE ELSE FALSE END AS entregue_no_prazo
FROM modelado.orders AS orders
JOIN modelado.customers AS customers ON orders.customer_id=customers.customer_id;
SELECT COUNT(*) AS total_vw_orders_base FROM modelado.vw_orders_base;


-- Resultado: 99.441 registros.

-- =====================================================
-- 6.2 VW_ORDER_ITEMS_BASE
-- Granularidade: 1 linha por item de pedido
-- Objetivo: reunir item, produto, categoria, seller, preço e frete
-- =====================================================
CREATE OR REPLACE VIEW modelado.vw_order_items_base AS
SELECT
    order_items.order_id,
    order_items.order_item_id,
    order_items.product_id,
    products.product_category_name,
    product_category_translation.product_category_name_english,
    COALESCE(product_category_translation.product_category_name_english,products.product_category_name,'sem_categoria') AS categoria_analise,
    order_items.seller_id,
    sellers.seller_city,
    sellers.seller_state,
    order_items.shipping_limit_date,
    order_items.price,
    order_items.freight_value,
    ROUND(order_items.price+order_items.freight_value,2) AS valor_item_total
FROM modelado.order_items AS order_items
JOIN modelado.products AS products ON order_items.product_id=products.product_id
LEFT JOIN modelado.product_category_translation AS product_category_translation ON products.product_category_name=product_category_translation.product_category_name
JOIN modelado.sellers AS sellers ON order_items.seller_id=sellers.seller_id;
SELECT COUNT(*) AS total_vw_order_items_base FROM modelado.vw_order_items_base;


-- Resultado: 112.650 registros.

-- =====================================================
-- 6.3 VW_PAYMENTS_ORDER
-- Granularidade: 1 linha por pedido
-- Objetivo: consolidar múltiplos pagamentos antes dos JOINs analíticos
-- =====================================================
CREATE OR REPLACE VIEW modelado.vw_payments_order AS
SELECT
    order_payments.order_id,
    COUNT(*) AS quantidade_registros_pagamento,
    COUNT(DISTINCT order_payments.payment_type) AS quantidade_formas_pagamento,
    STRING_AGG(DISTINCT order_payments.payment_type,', ' ORDER BY order_payments.payment_type) AS formas_pagamento,
    MAX(order_payments.payment_installments) AS maior_numero_parcelas,
    ROUND(SUM(order_payments.payment_value),2) AS total_pago,
    BOOL_OR(order_payments.payment_value=0) AS possui_pagamento_valor_zero,
    BOOL_OR(order_payments.payment_installments=0) AS possui_parcelamento_zero
FROM modelado.order_payments AS order_payments
GROUP BY order_payments.order_id;
SELECT COUNT(*) AS total_vw_payments_order FROM modelado.vw_payments_order;

-- Resultado: 99.440 pedidos com registro de pagamento.

-- =====================================================
-- 6.4 VW_REVIEWS_ORDER
-- Granularidade: 1 linha por pedido
-- Objetivo: consolidar múltiplas avaliações sem eliminar a informação
-- =====================================================
CREATE OR REPLACE VIEW modelado.vw_reviews_order AS
SELECT
    order_reviews.order_id,
    COUNT(*) AS quantidade_avaliacoes,
    ROUND(AVG(order_reviews.review_score),2) AS nota_media,
    MIN(order_reviews.review_score) AS menor_nota,
    MAX(order_reviews.review_score) AS maior_nota,
    COUNT(order_reviews.review_comment_title) AS quantidade_titulos,
    COUNT(order_reviews.review_comment_message) AS quantidade_comentarios
FROM modelado.order_reviews AS order_reviews
GROUP BY order_reviews.order_id;
SELECT COUNT(*) AS total_vw_reviews_order FROM modelado.vw_reviews_order;


-- Resultado: 98.673 pedidos com avaliação.


-- =====================================================
-- 6.5 VW_ORDERS_ANALYTICS
-- Granularidade: 1 linha por pedido
-- Objetivo: criar a principal base analítica do projeto
-- =====================================================
CREATE OR REPLACE VIEW modelado.vw_orders_analytics AS
WITH itens_por_pedido AS (
SELECT
    order_items_base.order_id,
    COUNT(*) AS quantidade_itens,
    COUNT(DISTINCT order_items_base.product_id) AS quantidade_produtos,
    COUNT(DISTINCT order_items_base.seller_id) AS quantidade_sellers,
    ROUND(SUM(order_items_base.price),2) AS valor_produtos,
    ROUND(SUM(order_items_base.freight_value),2) AS valor_frete,
    ROUND(SUM(order_items_base.valor_item_total),2) AS valor_pedido
FROM modelado.vw_order_items_base AS order_items_base
GROUP BY order_items_base.order_id
)
SELECT
    orders_base.order_id,
    orders_base.customer_id,
    orders_base.customer_unique_id,
    orders_base.order_status,
    orders_base.pedido_valido,
    orders_base.order_purchase_timestamp,
    orders_base.order_approved_at,
    orders_base.order_delivered_carrier_date,
    orders_base.order_delivered_customer_date,
    orders_base.order_estimated_delivery_date,
    orders_base.customer_zip_code_prefix,
    orders_base.customer_city,
    orders_base.customer_state,
    orders_base.dias_para_entrega,
    orders_base.diferenca_prazo_dias,
    orders_base.dias_atraso,
    orders_base.entregue_no_prazo,
    COALESCE(itens_por_pedido.quantidade_itens,0) AS quantidade_itens,
    COALESCE(itens_por_pedido.quantidade_produtos,0) AS quantidade_produtos,
    COALESCE(itens_por_pedido.quantidade_sellers,0) AS quantidade_sellers,
    COALESCE(itens_por_pedido.valor_produtos,0) AS valor_produtos,
    COALESCE(itens_por_pedido.valor_frete,0) AS valor_frete,
    COALESCE(itens_por_pedido.valor_pedido,0) AS valor_pedido,
    COALESCE(payments_order.quantidade_registros_pagamento,0) AS quantidade_registros_pagamento,
    COALESCE(payments_order.quantidade_formas_pagamento,0) AS quantidade_formas_pagamento,
    payments_order.formas_pagamento,
    payments_order.maior_numero_parcelas,
    payments_order.total_pago,
    payments_order.possui_pagamento_valor_zero,
    payments_order.possui_parcelamento_zero,
    CASE WHEN payments_order.total_pago IS NOT NULL THEN ROUND(payments_order.total_pago-COALESCE(itens_por_pedido.valor_pedido,0),2) END AS diferenca_pagamento_pedido,
    COALESCE(reviews_order.quantidade_avaliacoes,0) AS quantidade_avaliacoes,
    reviews_order.nota_media,
    reviews_order.menor_nota,
    reviews_order.maior_nota,
    COALESCE(reviews_order.quantidade_titulos,0) AS quantidade_titulos,
    COALESCE(reviews_order.quantidade_comentarios,0) AS quantidade_comentarios
FROM modelado.vw_orders_base AS orders_base
LEFT JOIN itens_por_pedido ON orders_base.order_id=itens_por_pedido.order_id
LEFT JOIN modelado.vw_payments_order AS payments_order ON orders_base.order_id=payments_order.order_id
LEFT JOIN modelado.vw_reviews_order AS reviews_order ON orders_base.order_id=reviews_order.order_id;
SELECT COUNT(*) AS total_vw_orders_analytics FROM modelado.vw_orders_analytics;

-- Resultado: 99.441 registros.

-- =====================================================
-- 6.6 VW_CUSTOMERS_ANALYTICS
-- Granularidade: 1 linha por customer_unique_id
-- Objetivo: analisar recorrência, valor e comportamento do cliente
-- =====================================================
CREATE OR REPLACE VIEW modelado.vw_customers_analytics AS
SELECT
    orders_analytics.customer_unique_id,
    COUNT(DISTINCT orders_analytics.customer_id) AS quantidade_customer_ids,
    COUNT(*) AS total_pedidos,
    COUNT(*) FILTER (WHERE orders_analytics.pedido_valido) AS pedidos_validos,
    MIN(orders_analytics.order_purchase_timestamp) FILTER (WHERE orders_analytics.pedido_valido) AS primeira_compra,
    MAX(orders_analytics.order_purchase_timestamp) FILTER (WHERE orders_analytics.pedido_valido) AS ultima_compra,
    ((MAX(orders_analytics.order_purchase_timestamp) FILTER (WHERE orders_analytics.pedido_valido))::DATE-(MIN(orders_analytics.order_purchase_timestamp) FILTER (WHERE orders_analytics.pedido_valido))::DATE) AS dias_entre_primeira_ultima_compra,
    ROUND(COALESCE(SUM(orders_analytics.valor_pedido) FILTER (WHERE orders_analytics.pedido_valido),0),2) AS valor_total_comprado,
    ROUND(AVG(orders_analytics.valor_pedido) FILTER (WHERE orders_analytics.pedido_valido),2) AS ticket_medio,
    ROUND(AVG(orders_analytics.nota_media) FILTER (WHERE orders_analytics.pedido_valido AND orders_analytics.nota_media IS NOT NULL),2) AS avaliacao_media,
    (COUNT(*) FILTER (WHERE orders_analytics.pedido_valido)>1) AS cliente_recorrente
FROM modelado.vw_orders_analytics AS orders_analytics
GROUP BY orders_analytics.customer_unique_id;
SELECT COUNT(*) AS total_vw_customers_analytics FROM modelado.vw_customers_analytics;

-- Resultado: 96.096 clientes únicos.

-- =====================================================
-- 6.7 VW_PRODUCTS_ANALYTICS
-- Granularidade: 1 linha por produto
-- Objetivo: consolidar desempenho comercial e satisfação por produto
-- =====================================================
CREATE OR REPLACE VIEW modelado.vw_products_analytics AS
WITH metricas_produto AS (
SELECT
    order_items_base.product_id,
    COUNT(*) FILTER (WHERE orders_base.pedido_valido) AS itens_vendidos,
    COUNT(DISTINCT order_items_base.order_id) FILTER (WHERE orders_base.pedido_valido) AS pedidos_validos,
    COUNT(DISTINCT order_items_base.seller_id) FILTER (WHERE orders_base.pedido_valido) AS quantidade_sellers,
    ROUND(SUM(order_items_base.price) FILTER (WHERE orders_base.pedido_valido),2) AS valor_produtos,
    ROUND(SUM(order_items_base.freight_value) FILTER (WHERE orders_base.pedido_valido),2) AS valor_frete,
    ROUND(SUM(order_items_base.valor_item_total) FILTER (WHERE orders_base.pedido_valido),2) AS valor_total_com_frete,
    ROUND(AVG(order_items_base.price) FILTER (WHERE orders_base.pedido_valido),2) AS preco_medio
FROM modelado.vw_order_items_base AS order_items_base
JOIN modelado.vw_orders_base AS orders_base ON order_items_base.order_id=orders_base.order_id
GROUP BY order_items_base.product_id
),
avaliacoes_produto AS (
SELECT
    produto_pedido.product_id,
    ROUND(AVG(produto_pedido.nota_media),2) AS avaliacao_media
FROM (
SELECT DISTINCT
    order_items_base.product_id,
    order_items_base.order_id,
    reviews_order.nota_media
FROM modelado.vw_order_items_base AS order_items_base
JOIN modelado.vw_orders_base AS orders_base ON order_items_base.order_id=orders_base.order_id
JOIN modelado.vw_reviews_order AS reviews_order ON order_items_base.order_id=reviews_order.order_id
WHERE orders_base.pedido_valido AND reviews_order.nota_media IS NOT NULL
) AS produto_pedido
GROUP BY produto_pedido.product_id
)
SELECT
    products.product_id,
    products.product_category_name,
    product_category_translation.product_category_name_english,
    COALESCE(product_category_translation.product_category_name_english,products.product_category_name,'sem_categoria') AS categoria_analise,
    products.product_name_length,
    products.product_description_length,
    products.product_photos_qty,
    products.product_weight_g,
    products.product_length_cm,
    products.product_height_cm,
    products.product_width_cm,
    COALESCE(metricas_produto.itens_vendidos,0) AS itens_vendidos,
    COALESCE(metricas_produto.pedidos_validos,0) AS pedidos_validos,
    COALESCE(metricas_produto.quantidade_sellers,0) AS quantidade_sellers,
    COALESCE(metricas_produto.valor_produtos,0) AS valor_produtos,
    COALESCE(metricas_produto.valor_frete,0) AS valor_frete,
    COALESCE(metricas_produto.valor_total_com_frete,0) AS valor_total_com_frete,
    metricas_produto.preco_medio,
    avaliacoes_produto.avaliacao_media
FROM modelado.products AS products
LEFT JOIN modelado.product_category_translation AS product_category_translation ON products.product_category_name=product_category_translation.product_category_name
LEFT JOIN metricas_produto ON products.product_id=metricas_produto.product_id
LEFT JOIN avaliacoes_produto ON products.product_id=avaliacoes_produto.product_id;
SELECT COUNT(*) AS total_vw_products_analytics FROM modelado.vw_products_analytics;

-- Resultado: 32.951 produtos.

-- =====================================================
-- 6.8 VW_SELLERS_ANALYTICS
-- Granularidade: 1 linha por seller
-- Objetivo: consolidar vendas, pedidos, logística e satisfação por seller
-- =====================================================
CREATE OR REPLACE VIEW modelado.vw_sellers_analytics AS
WITH metricas_seller AS (
SELECT
    order_items_base.seller_id,
    COUNT(*) FILTER (WHERE orders_base.pedido_valido) AS itens_vendidos,
    COUNT(DISTINCT order_items_base.order_id) FILTER (WHERE orders_base.pedido_valido) AS pedidos_validos,
    COUNT(DISTINCT order_items_base.product_id) FILTER (WHERE orders_base.pedido_valido) AS produtos_vendidos,
    ROUND(SUM(order_items_base.price) FILTER (WHERE orders_base.pedido_valido),2) AS valor_produtos,
    ROUND(SUM(order_items_base.freight_value) FILTER (WHERE orders_base.pedido_valido),2) AS valor_frete,
    ROUND(SUM(order_items_base.valor_item_total) FILTER (WHERE orders_base.pedido_valido),2) AS valor_total_com_frete,
    ROUND((SUM(order_items_base.valor_item_total) FILTER (WHERE orders_base.pedido_valido))/NULLIF(COUNT(DISTINCT order_items_base.order_id) FILTER (WHERE orders_base.pedido_valido),0),2) AS ticket_medio_por_pedido
FROM modelado.vw_order_items_base AS order_items_base
JOIN modelado.vw_orders_base AS orders_base ON order_items_base.order_id=orders_base.order_id
GROUP BY order_items_base.seller_id
),
seller_pedido AS (
SELECT DISTINCT
    order_items_base.seller_id,
    order_items_base.order_id,
    orders_base.dias_para_entrega,
    orders_base.entregue_no_prazo,
    reviews_order.nota_media
FROM modelado.vw_order_items_base AS order_items_base
JOIN modelado.vw_orders_base AS orders_base ON order_items_base.order_id=orders_base.order_id
LEFT JOIN modelado.vw_reviews_order AS reviews_order ON order_items_base.order_id=reviews_order.order_id
WHERE orders_base.pedido_valido
),
experiencia_seller AS (
SELECT
    seller_pedido.seller_id,
    ROUND(AVG(seller_pedido.nota_media) FILTER (WHERE seller_pedido.nota_media IS NOT NULL),2) AS avaliacao_media,
    ROUND(AVG(seller_pedido.dias_para_entrega) FILTER (WHERE seller_pedido.dias_para_entrega IS NOT NULL),2) AS dias_medio_entrega,
    ROUND((100.0*COUNT(*) FILTER (WHERE seller_pedido.entregue_no_prazo=FALSE))/NULLIF(COUNT(*) FILTER (WHERE seller_pedido.entregue_no_prazo IS NOT NULL),0),2) AS percentual_pedidos_atrasados
FROM seller_pedido
GROUP BY seller_pedido.seller_id
)
SELECT
    sellers.seller_id,
    sellers.seller_zip_code_prefix,
    sellers.seller_city,
    sellers.seller_state,
    COALESCE(metricas_seller.itens_vendidos,0) AS itens_vendidos,
    COALESCE(metricas_seller.pedidos_validos,0) AS pedidos_validos,
    COALESCE(metricas_seller.produtos_vendidos,0) AS produtos_vendidos,
    COALESCE(metricas_seller.valor_produtos,0) AS valor_produtos,
    COALESCE(metricas_seller.valor_frete,0) AS valor_frete,
    COALESCE(metricas_seller.valor_total_com_frete,0) AS valor_total_com_frete,
    metricas_seller.ticket_medio_por_pedido,
    experiencia_seller.avaliacao_media,
    experiencia_seller.dias_medio_entrega,
    experiencia_seller.percentual_pedidos_atrasados
FROM modelado.sellers AS sellers
LEFT JOIN metricas_seller ON sellers.seller_id=metricas_seller.seller_id
LEFT JOIN experiencia_seller ON sellers.seller_id=experiencia_seller.seller_id;
SELECT COUNT(*) AS total_vw_sellers_analytics FROM modelado.vw_sellers_analytics;

-- Resultado: 3.095 sellers.

-- =====================================================
-- 6.9 VW_CATEGORIES_ANALYTICS
-- Granularidade: 1 linha por categoria de produto
-- Objetivo: consolidar volume, valor, satisfação e logística por categoria
-- =====================================================
CREATE OR REPLACE VIEW modelado.vw_categories_analytics AS
WITH categorias AS (
SELECT DISTINCT
    COALESCE(products.product_category_name,'sem_categoria') AS categoria_origem,
    product_category_translation.product_category_name_english AS categoria_ingles,
    COALESCE(product_category_translation.product_category_name_english,products.product_category_name,'sem_categoria') AS categoria_analise
FROM modelado.products AS products
LEFT JOIN modelado.product_category_translation AS product_category_translation ON products.product_category_name=product_category_translation.product_category_name
),
metricas_categoria AS (
SELECT
    COALESCE(order_items_base.product_category_name,'sem_categoria') AS categoria_origem,
    COUNT(*) FILTER (WHERE orders_base.pedido_valido) AS itens_vendidos,
    COUNT(DISTINCT order_items_base.order_id) FILTER (WHERE orders_base.pedido_valido) AS pedidos_validos,
    COUNT(DISTINCT order_items_base.product_id) FILTER (WHERE orders_base.pedido_valido) AS produtos_vendidos,
    COUNT(DISTINCT order_items_base.seller_id) FILTER (WHERE orders_base.pedido_valido) AS sellers,
    ROUND(SUM(order_items_base.price) FILTER (WHERE orders_base.pedido_valido),2) AS valor_produtos,
    ROUND(SUM(order_items_base.freight_value) FILTER (WHERE orders_base.pedido_valido),2) AS valor_frete,
    ROUND(SUM(order_items_base.valor_item_total) FILTER (WHERE orders_base.pedido_valido),2) AS valor_total_com_frete,
    ROUND(AVG(order_items_base.price) FILTER (WHERE orders_base.pedido_valido),2) AS preco_medio_item
FROM modelado.vw_order_items_base AS order_items_base
JOIN modelado.vw_orders_base AS orders_base ON order_items_base.order_id=orders_base.order_id
GROUP BY COALESCE(order_items_base.product_category_name,'sem_categoria')
),
categoria_pedido AS (
SELECT DISTINCT
    COALESCE(order_items_base.product_category_name,'sem_categoria') AS categoria_origem,
    order_items_base.order_id,
    orders_base.dias_para_entrega,
    orders_base.entregue_no_prazo,
    reviews_order.nota_media
FROM modelado.vw_order_items_base AS order_items_base
JOIN modelado.vw_orders_base AS orders_base ON order_items_base.order_id=orders_base.order_id
LEFT JOIN modelado.vw_reviews_order AS reviews_order ON order_items_base.order_id=reviews_order.order_id
WHERE orders_base.pedido_valido
),
experiencia_categoria AS (
SELECT
    categoria_pedido.categoria_origem,
    ROUND(AVG(categoria_pedido.nota_media) FILTER (WHERE categoria_pedido.nota_media IS NOT NULL),2) AS avaliacao_media,
    ROUND(AVG(categoria_pedido.dias_para_entrega) FILTER (WHERE categoria_pedido.dias_para_entrega IS NOT NULL),2) AS dias_medio_entrega,
    ROUND((100.0*COUNT(*) FILTER (WHERE categoria_pedido.entregue_no_prazo=FALSE))/NULLIF(COUNT(*) FILTER (WHERE categoria_pedido.entregue_no_prazo IS NOT NULL),0),2) AS percentual_pedidos_atrasados
FROM categoria_pedido
GROUP BY categoria_pedido.categoria_origem
)
SELECT
    categorias.categoria_origem,
    categorias.categoria_ingles,
    categorias.categoria_analise,
    COALESCE(metricas_categoria.itens_vendidos,0) AS itens_vendidos,
    COALESCE(metricas_categoria.pedidos_validos,0) AS pedidos_validos,
    COALESCE(metricas_categoria.produtos_vendidos,0) AS produtos_vendidos,
    COALESCE(metricas_categoria.sellers,0) AS sellers,
    COALESCE(metricas_categoria.valor_produtos,0) AS valor_produtos,
    COALESCE(metricas_categoria.valor_frete,0) AS valor_frete,
    COALESCE(metricas_categoria.valor_total_com_frete,0) AS valor_total_com_frete,
    metricas_categoria.preco_medio_item,
    experiencia_categoria.avaliacao_media,
    experiencia_categoria.dias_medio_entrega,
    experiencia_categoria.percentual_pedidos_atrasados
FROM categorias
LEFT JOIN metricas_categoria ON categorias.categoria_origem=metricas_categoria.categoria_origem
LEFT JOIN experiencia_categoria ON categorias.categoria_origem=experiencia_categoria.categoria_origem;
SELECT COUNT(*) AS total_vw_categories_analytics FROM modelado.vw_categories_analytics;

-- Resultado: 74 

-- =====================================================
-- 6.10 VW_GEOLOCATION_ZIP
-- Granularidade: 1 linha por prefixo de CEP
-- Objetivo: criar coordenadas consolidadas para mapas e análises geográficas
-- =====================================================
CREATE OR REPLACE VIEW modelado.vw_geolocation_zip AS
SELECT
    geolocation.geolocation_zip_code_prefix,
    ROUND(AVG(geolocation.geolocation_lat),8) AS latitude_media,
    ROUND(AVG(geolocation.geolocation_lng),8) AS longitude_media,
    COUNT(*) AS quantidade_pontos,
    COUNT(DISTINCT geolocation.geolocation_city) AS quantidade_cidades,
    COUNT(DISTINCT geolocation.geolocation_state) AS quantidade_estados
FROM modelado.geolocation AS geolocation
GROUP BY geolocation.geolocation_zip_code_prefix;
SELECT COUNT(*) AS total_vw_geolocation_zip FROM modelado.vw_geolocation_zip;

-- Resultado: aproximadamente 19.015 prefixos de CEP.


-- =====================================================
-- 6.11 DIM_CALENDAR
-- Granularidade: 1 linha por data
-- Objetivo: disponibilizar atributos temporais para Python e dashboard
-- =====================================================
CREATE OR REPLACE VIEW modelado.dim_calendar AS
WITH limites AS (
SELECT
    LEAST(MIN(orders.order_purchase_timestamp)::DATE,MIN(orders.order_approved_at)::DATE,MIN(orders.order_delivered_carrier_date)::DATE,MIN(orders.order_delivered_customer_date)::DATE,MIN(orders.order_estimated_delivery_date)::DATE) AS data_minima,
    GREATEST(MAX(orders.order_purchase_timestamp)::DATE,MAX(orders.order_approved_at)::DATE,MAX(orders.order_delivered_carrier_date)::DATE,MAX(orders.order_delivered_customer_date)::DATE,MAX(orders.order_estimated_delivery_date)::DATE) AS data_maxima
FROM modelado.orders AS orders
),
datas AS (
SELECT GENERATE_SERIES(limites.data_minima,limites.data_maxima,INTERVAL '1 day')::DATE AS data
FROM limites
)
SELECT
    datas.data,
    EXTRACT(YEAR FROM datas.data)::INTEGER AS ano,
    EXTRACT(QUARTER FROM datas.data)::INTEGER AS trimestre,
    EXTRACT(MONTH FROM datas.data)::INTEGER AS mes,
    CASE EXTRACT(MONTH FROM datas.data)::INTEGER
        WHEN 1 THEN 'Janeiro'
        WHEN 2 THEN 'Fevereiro'
        WHEN 3 THEN 'Março'
        WHEN 4 THEN 'Abril'
        WHEN 5 THEN 'Maio'
        WHEN 6 THEN 'Junho'
        WHEN 7 THEN 'Julho'
        WHEN 8 THEN 'Agosto'
        WHEN 9 THEN 'Setembro'
        WHEN 10 THEN 'Outubro'
        WHEN 11 THEN 'Novembro'
        WHEN 12 THEN 'Dezembro'
    END AS nome_mes,
    TO_CHAR(datas.data,'YYYY-MM') AS ano_mes,
    EXTRACT(WEEK FROM datas.data)::INTEGER AS semana_ano,
    EXTRACT(DAY FROM datas.data)::INTEGER AS dia_mes,
    EXTRACT(ISODOW FROM datas.data)::INTEGER AS dia_semana,
    CASE EXTRACT(ISODOW FROM datas.data)::INTEGER
        WHEN 1 THEN 'Segunda-feira'
        WHEN 2 THEN 'Terça-feira'
        WHEN 3 THEN 'Quarta-feira'
        WHEN 4 THEN 'Quinta-feira'
        WHEN 5 THEN 'Sexta-feira'
        WHEN 6 THEN 'Sábado'
        WHEN 7 THEN 'Domingo'
    END AS nome_dia_semana,
    (EXTRACT(ISODOW FROM datas.data)::INTEGER IN (6,7)) AS fim_de_semana
FROM datas;
SELECT MIN(data) AS data_inicial,MAX(data) AS data_final,COUNT(*) AS total_datas
FROM modelado.dim_calendar;

-- =====================================================
-- CONCLUSÃO DA FASE 06 - CAMADAS ANALÍTICAS
-- =====================================================
-- As views analíticas foram estruturadas para separar granularidades
-- e evitar duplicidade de métricas causada por JOINs entre tabelas 1:N.
-- vw_orders_analytics será a principal base no nível de pedido.
-- vw_order_items_base apoiará análises detalhadas de produto, categoria e seller.
-- Pagamentos e avaliações foram previamente consolidados por pedido.
-- As views de clientes, produtos, sellers e categorias fornecem bases agregadas
-- para exploração no Python e consumo no dashboard.
-- vw_geolocation_zip prepara coordenadas consolidadas para mapas.
-- dim_calendar fornece atributos temporais reutilizáveis.
-- A próxima etapa do projeto será a EDA e análise aprofundada em Python.
