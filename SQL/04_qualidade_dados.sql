-- =====================================================
-- PROJETO OLIST E-COMMERCE
-- 04. QUALIDADE DOS DADOS
-- =====================================================
/*
Objetivo:
Avaliar a qualidade dos dados carregados no staging,
identificando valores ausentes, strings vazias,
duplicidades e outras inconsistências antes da criação
do modelo relacional definitivo.
*/


-- =====================================================
-- 4.1 PRODUCTS - CATEGORIAS AUSENTES
-- Verificar NULL, strings vazias e categorias preenchidas
-- =====================================================
SELECT COUNT(*) AS total_produtos,
COUNT(*) FILTER (WHERE product_category_name IS NULL) AS valores_null,
COUNT(*) FILTER (WHERE TRIM(product_category_name) = '') AS strings_vazias,
COUNT(*) FILTER (WHERE NULLIF(TRIM(product_category_name), '') IS NOT NULL) AS categorias_preenchidas
FROM staging.olist_products_dataset;


-- Conclusão:
-- Foram identificados 610 produtos sem categoria informada.
-- Esses registros não estão armazenados como NULL, mas como strings vazias ('').
-- Os demais 32.341 produtos possuem product_category_name preenchido.
-- Portanto, strings vazias deverão ser padronizadas como NULL na etapa de tratamento.


-- =====================================================
-- 4.2 PRODUCTS - ATRIBUTOS AUSENTES
-- Verificar valores nulos nos atributos dos produtos
-- =====================================================
SELECT COUNT(*) AS total_produtos,
COUNT(*) FILTER (WHERE product_name_lenght IS NULL) AS nome_ausente,
COUNT(*) FILTER (WHERE product_description_lenght IS NULL) AS descricao_ausente,
COUNT(*) FILTER (WHERE product_photos_qty IS NULL) AS fotos_ausentes,
COUNT(*) FILTER (WHERE product_weight_g IS NULL) AS peso_ausente,
COUNT(*) FILTER (WHERE product_length_cm IS NULL) AS comprimento_ausente,
COUNT(*) FILTER (WHERE product_height_cm IS NULL) AS altura_ausente,
COUNT(*) FILTER (WHERE product_width_cm IS NULL) AS largura_ausente
FROM staging.olist_products_dataset;

-- Conclusão:
-- Foram identificados 610 produtos sem informações de nome,
-- descrição e quantidade de fotos.
-- Também foram encontrados 2 produtos sem informações de peso
-- e dimensões físicas.
-- A coincidência de 610 registros em diferentes atributos sugere
-- um padrão comum de ausência de dados, que será investigado na sequência.


-- =====================================================
-- 4.2.1 PRODUCTS - PADRÃO DE AUSÊNCIA
-- Verificar se os 610 produtos sem categoria também não possuem atributos descritivos
-- =====================================================
SELECT COUNT(*) AS produtos_sem_categoria,
COUNT(*) FILTER (WHERE product_name_lenght IS NULL) AS tambem_sem_nome,
COUNT(*) FILTER (WHERE product_description_lenght IS NULL) AS tambem_sem_descricao,
COUNT(*) FILTER (WHERE product_photos_qty IS NULL) AS tambem_sem_fotos
FROM staging.olist_products_dataset
WHERE NULLIF(TRIM(product_category_name), '') IS NULL;

-- Conclusão:
-- Os 610 produtos sem categoria são exatamente os mesmos registros
-- que também não possuem nome, descrição e quantidade de fotos.
-- Portanto, não se tratam de ausências isoladas por atributo,
-- mas de um padrão concentrado no mesmo conjunto de produtos.
-- Esses registros deverão receber tratamento específico na modelagem.

-- =====================================================
-- 4.2.2 PRODUCTS - DIMENSÕES AUSENTES
-- Identificar produtos sem peso ou dimensões físicas
-- =====================================================
SELECT product_id, product_category_name, product_weight_g, product_length_cm, product_height_cm, product_width_cm
FROM staging.olist_products_dataset
WHERE product_weight_g IS NULL
OR product_length_cm IS NULL
OR product_height_cm IS NULL
OR product_width_cm IS NULL;

-- Conclusão:
-- Foram identificados 2 produtos sem peso e dimensões físicas.
-- Em ambos os registros estão ausentes product_weight_g,
-- product_length_cm, product_height_cm e product_width_cm.
-- Um dos produtos possui categoria "bebes", enquanto o outro
-- também apresenta ausência de categoria.
-- Portanto, a ausência de dimensões não ocorre exclusivamente
-- nos 610 produtos sem informações descritivas.


-- =====================================================
-- 4.2.3 PRODUCTS - PERFIL DOS PRODUTOS SEM DIMENSÕES
-- Verificar demais atributos dos produtos sem dimensões físicas
-- =====================================================
SELECT product_id, product_category_name, product_name_lenght, product_description_lenght, product_photos_qty
FROM staging.olist_products_dataset
WHERE product_weight_g IS NULL
OR product_length_cm IS NULL
OR product_height_cm IS NULL
OR product_width_cm IS NULL;

-- Conclusão:
-- Os 2 produtos sem dimensões apresentam perfis diferentes.
-- O produto da categoria "bebes" possui nome, descrição e fotos preenchidos,
-- indicando uma inconsistência isolada apenas nos atributos físicos.
-- O segundo produto também não possui categoria, nome, descrição ou fotos,
-- fazendo parte do grupo de 610 produtos com informações descritivas ausentes.

-- =====================================================
-- 4.3 ORDERS - DADOS AUSENTES
-- Verificar ausência nos campos de status e datas do pedido
-- =====================================================
SELECT COUNT(*) AS total_pedidos,
COUNT(*) FILTER (WHERE NULLIF(TRIM(order_status), '') IS NULL) AS status_ausente,
COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) AS compra_ausente,
COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS aprovacao_ausente,
COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS envio_transportadora_ausente,
COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS entrega_cliente_ausente,
COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL) AS previsao_entrega_ausente
FROM staging.olist_orders_dataset;

-- Conclusão:
-- Todos os 99.441 pedidos possuem status, data de compra e previsão de entrega.
-- Foram identificados 160 pedidos sem data de aprovação,
-- 1.783 sem data de envio para a transportadora
-- e 2.965 sem data de entrega ao cliente.
-- Essas ausências não devem ser tratadas imediatamente como erro,
-- pois podem estar relacionadas ao status do pedido.
-- Será necessário cruzar os campos ausentes com order_status.

-- =====================================================
-- 4.3.1 ORDERS - AUSÊNCIAS POR STATUS
-- Verificar como as datas ausentes se distribuem por status
-- =====================================================
SELECT order_status,
COUNT(*) AS total_pedidos,
COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS aprovacao_ausente,
COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS envio_transportadora_ausente,
COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS entrega_cliente_ausente
FROM staging.olist_orders_dataset
GROUP BY order_status
ORDER BY total_pedidos DESC;


-- Conclusão:
-- A maior parte das datas ausentes é coerente com o status do pedido.
-- Pedidos shipped ainda não possuem data de entrega ao cliente,
-- enquanto pedidos canceled, unavailable, invoiced, processing,
-- created e approved podem não ter avançado por todas as etapas logísticas.
-- Entretanto, foram identificadas inconsistências em pedidos com status delivered:
-- 14 pedidos sem data de aprovação,
-- 2 pedidos sem data de envio para a transportadora
-- e 8 pedidos sem data de entrega ao cliente.
-- Esses registros serão investigados separadamente como possíveis problemas
-- de qualidade dos dados.


-- =====================================================
-- 4.3.2 ORDERS - INCONSISTÊNCIAS EM PEDIDOS ENTREGUES
-- Quantificar pedidos delivered com datas críticas ausentes
-- =====================================================
SELECT COUNT(*) AS registros_encontrados,
COUNT(DISTINCT order_id) AS pedidos_distintos
FROM staging.olist_orders_dataset
WHERE order_status = 'delivered'
AND (order_approved_at IS NULL
OR order_delivered_carrier_date IS NULL
OR order_delivered_customer_date IS NULL);

-- =====================================================
-- 4.3.2.1 DETALHAMENTO DOS PEDIDOS INCONSISTENTES
-- =====================================================
SELECT ROW_NUMBER() OVER (ORDER BY order_purchase_timestamp) AS registro,
order_id,
order_status,
order_purchase_timestamp,
order_approved_at,
order_delivered_carrier_date,
order_delivered_customer_date,
order_estimated_delivery_date
FROM staging.olist_orders_dataset
WHERE order_status = 'delivered'
AND (order_approved_at IS NULL
OR order_delivered_carrier_date IS NULL
OR order_delivered_customer_date IS NULL)
ORDER BY order_purchase_timestamp;

-- Conclusão:
-- Foram identificados 23 pedidos distintos com status delivered
-- que apresentam pelo menos uma data crítica ausente.
-- 14 pedidos não possuem data de aprovação,
-- 2 não possuem data de envio para a transportadora
-- e 8 não possuem data de entrega ao cliente.
-- Um pedido apresenta simultaneamente ausência da data de envio
-- e da data de entrega ao cliente.
-- A numeração criada com ROW_NUMBER facilita a leitura dos registros,
-- enquanto order_id permanece como identificador único do pedido.
-- As ausências em pedidos já classificados como delivered indicam
-- inconsistências de qualidade que deverão ser consideradas no tratamento.

-- =====================================================
-- 4.3.3 ORDERS - CONSISTÊNCIA CRONOLÓGICA
-- Verificar possíveis datas em ordem incoerente
-- =====================================================
SELECT
COUNT(*) FILTER (WHERE order_approved_at IS NOT NULL AND order_approved_at < order_purchase_timestamp) AS aprovacao_antes_compra,
COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NOT NULL AND order_delivered_carrier_date < order_purchase_timestamp) AS envio_antes_compra,
COUNT(*) FILTER (WHERE order_delivered_customer_date IS NOT NULL AND order_delivered_customer_date < order_purchase_timestamp) AS entrega_antes_compra,
COUNT(*) FILTER (WHERE order_delivered_customer_date IS NOT NULL AND order_delivered_carrier_date IS NOT NULL AND order_delivered_customer_date < order_delivered_carrier_date) AS entrega_antes_envio
FROM staging.olist_orders_dataset;


-- Conclusão:
-- Não foram identificados pedidos aprovados ou entregues antes da data de compra.
-- Entretanto, foram encontrados 166 pedidos com data de envio para a transportadora
-- anterior à data de compra e 23 pedidos com data de entrega ao cliente
-- anterior à data de envio para a transportadora.
-- Esses casos representam inconsistências cronológicas e precisam ser investigados
-- antes de utilizar essas datas em análises de prazo e desempenho logístico.


-- =====================================================
-- 4.3.3.1 ORDERS - PEDIDOS COM INCONSISTÊNCIA CRONOLÓGICA
-- Quantificar pedidos distintos envolvidos
-- =====================================================
SELECT COUNT(*) AS pedidos_com_inconsistencia
FROM staging.olist_orders_dataset
WHERE (order_delivered_carrier_date IS NOT NULL AND order_delivered_carrier_date < order_purchase_timestamp)
OR (order_delivered_customer_date IS NOT NULL AND order_delivered_carrier_date 
IS NOT NULL AND order_delivered_customer_date < order_delivered_carrier_date);


-- Conclusão:
-- Foram identificados 189 pedidos distintos com inconsistências cronológicas.
-- Desses, 166 possuem data de envio para a transportadora anterior à compra
-- e 23 possuem data de entrega ao cliente anterior à data de envio.
-- Como o total de pedidos distintos é igual à soma dos dois grupos,
-- não existem pedidos que apresentem simultaneamente as duas inconsistências.
-- Esses registros devem ser tratados antes de análises de prazo logístico.


-- =====================================================
-- 4.3.3.2 ORDERS - DETALHAMENTO DAS INCONSISTÊNCIAS
-- Classificar os pedidos pelo tipo de inconsistência cronológica
-- =====================================================
SELECT ROW_NUMBER() OVER (ORDER BY order_purchase_timestamp) AS registro,
order_id,
order_status,
order_purchase_timestamp,
order_delivered_carrier_date,
order_delivered_customer_date,
CASE
WHEN order_delivered_carrier_date < order_purchase_timestamp THEN 'Envio antes da compra'
WHEN order_delivered_customer_date < order_delivered_carrier_date THEN 'Entrega antes do envio'
END AS tipo_inconsistencia
FROM staging.olist_orders_dataset
WHERE (order_delivered_carrier_date IS NOT NULL AND order_delivered_carrier_date < order_purchase_timestamp)
OR (order_delivered_customer_date IS NOT NULL AND order_delivered_carrier_date IS NOT NULL AND order_delivered_customer_date < order_delivered_carrier_date)
ORDER BY order_purchase_timestamp;


-- Conclusão:
-- O detalhamento confirmou 189 pedidos distintos com inconsistências cronológicas.
-- Foram identificados 23 casos de entrega ao cliente anterior ao envio
-- para a transportadora e 166 casos de envio anterior à compra.
-- Dos 189 pedidos, 188 possuem status delivered e 1 possui status shipped.
-- As inconsistências aparecem em períodos diferentes da base,
-- indicando que o problema pode estar relacionado ao registro ou processamento
-- das datas e não apenas a ocorrências isoladas.

-- =====================================================
-- 4.3.3.3 ORDERS - RESUMO DAS INCONSISTÊNCIAS
-- Consolidar os casos por tipo e status
-- =====================================================
SELECT
CASE
WHEN order_delivered_carrier_date < order_purchase_timestamp THEN 'Envio antes da compra'
WHEN order_delivered_customer_date < order_delivered_carrier_date THEN 'Entrega antes do envio'
END AS tipo_inconsistencia,
order_status,
COUNT(*) AS total_pedidos
FROM staging.olist_orders_dataset
WHERE (order_delivered_carrier_date IS NOT NULL AND order_delivered_carrier_date < order_purchase_timestamp)
OR (order_delivered_customer_date IS NOT NULL AND order_delivered_carrier_date IS NOT NULL AND order_delivered_customer_date < order_delivered_carrier_date)
GROUP BY tipo_inconsistencia, order_status
ORDER BY tipo_inconsistencia, total_pedidos DESC;


-- Conclusão:
-- Foram identificados 189 pedidos com inconsistências cronológicas.
-- 23 pedidos delivered apresentam entrega ao cliente anterior ao envio.
-- 165 pedidos delivered apresentam envio anterior à data de compra.
-- 1 pedido shipped também apresenta envio anterior à data de compra.
-- Portanto, 188 inconsistências estão em pedidos delivered e 1 em pedido shipped.
-- Esses registros devem ser considerados antes de análises de prazo e desempenho logístico.


-- =====================================================
-- 4.4 ORDER PAYMENTS - QUALIDADE DOS PAGAMENTOS
-- Verificar campos ausentes e valores potencialmente inválidos
-- =====================================================
SELECT COUNT(*) AS total_pagamentos,
COUNT(*) FILTER (WHERE order_id IS NULL) AS order_id_ausente,
COUNT(*) FILTER (WHERE payment_sequential IS NULL) AS sequencial_ausente,
COUNT(*) FILTER (WHERE NULLIF(TRIM(payment_type), '') IS NULL) AS tipo_pagamento_ausente,
COUNT(*) FILTER (WHERE payment_installments IS NULL) AS parcelas_ausentes,
COUNT(*) FILTER (WHERE payment_value IS NULL) AS valor_ausente,
COUNT(*) FILTER (WHERE payment_installments <= 0) AS parcelas_invalidas,
COUNT(*) FILTER (WHERE payment_value <= 0) AS valores_nao_positivos
FROM staging.olist_order_payments_dataset;


-- Conclusão:
-- Os 103.886 registros de pagamento possuem os campos principais preenchidos.
-- Não foram identificados valores ausentes em order_id, payment_sequential,
-- payment_type, payment_installments ou payment_value.
-- Entretanto, foram encontrados 2 pagamentos com quantidade de parcelas
-- menor ou igual a zero e 9 pagamentos com valor menor ou igual a zero.
-- Esses registros serão detalhados para verificar se representam
-- inconsistências reais ou situações válidas do processo de pagamento.


-- =====================================================
-- 4.4.1 ORDER PAYMENTS - DETALHAMENTO DE VALORES ATÍPICOS
-- Identificar pagamentos com parcelas ou valores não positivos
-- =====================================================
SELECT ROW_NUMBER() OVER (ORDER BY order_id, payment_sequential) AS registro,
order_id,
payment_sequential,
payment_type,
payment_installments,
payment_value
FROM staging.olist_order_payments_dataset
WHERE payment_installments <= 0
OR payment_value <= 0
ORDER BY order_id, payment_sequential;

-- Conclusão:
-- Foram identificados 11 registros de pagamento com valores atípicos,
-- distribuídos em 10 pedidos distintos.
-- 2 pagamentos com credit_card possuem payment_installments igual a zero,
-- apesar de apresentarem payment_value positivo.
-- Também foram encontrados 9 pagamentos com payment_value igual a zero:
-- 6 do tipo voucher e 3 classificados como not_defined.
-- Um mesmo pedido possui dois registros de voucher com valor zero.
-- Esses casos precisam ser analisados no contexto completo do pagamento
-- antes de serem classificados como erros ou removidos da base.

-- =====================================================
-- 4.4.2 ORDER PAYMENTS - CONTEXTO DOS PAGAMENTOS COM VALOR ZERO
-- Verificar o pagamento total dos pedidos que possuem registros com valor zero
-- =====================================================
SELECT olist_order_payments_dataset.order_id,
COUNT(*) AS total_registros_pagamento,
COUNT(*) FILTER (WHERE payment_value = 0) AS pagamentos_valor_zero,
SUM(payment_value) AS valor_total_pedido
FROM staging.olist_order_payments_dataset
WHERE order_id IN (
SELECT DISTINCT order_id
FROM staging.olist_order_payments_dataset
WHERE payment_value = 0
)
GROUP BY olist_order_payments_dataset.order_id
ORDER BY olist_order_payments_dataset.order_id;


-- Conclusão:
-- Foram identificados 8 pedidos distintos contendo pagamentos com valor zero.
-- Em 5 pedidos, o registro com payment_value igual a zero está acompanhado
-- de outros pagamentos positivos, resultando em valor total do pedido maior que zero.
-- Portanto, nesses casos o registro zerado não representa necessariamente
-- ausência total de pagamento.
-- Entretanto, 3 pedidos apresentam valor total de pagamento igual a zero.
-- Esses pedidos precisam ser investigados separadamente antes de qualquer tratamento.


-- =====================================================
-- 4.4.2.1 ORDER PAYMENTS - PEDIDOS COM PAGAMENTO TOTAL ZERO
-- Verificar status dos pedidos cujo valor total de pagamento é zero
-- =====================================================
SELECT olist_order_payments_dataset.order_id,
olist_orders_dataset.order_status,
olist_orders_dataset.order_purchase_timestamp,
COUNT(*) AS registros_pagamento,
SUM(olist_order_payments_dataset.payment_value) AS valor_total_pagamento
FROM staging.olist_order_payments_dataset
JOIN staging.olist_orders_dataset
ON olist_order_payments_dataset.order_id = olist_orders_dataset.order_id
GROUP BY olist_order_payments_dataset.order_id,
olist_orders_dataset.order_status,
olist_orders_dataset.order_purchase_timestamp
HAVING SUM(olist_order_payments_dataset.payment_value) = 0
ORDER BY olist_order_payments_dataset.order_id;


-- Conclusão:
-- Os 3 pedidos com valor total de pagamento igual a zero
-- possuem status canceled.
-- Portanto, o valor zerado é compatível com pedidos que não foram concluídos
-- e não representa, por si só, uma inconsistência financeira.
-- Esses registros podem ser mantidos na base, desde que pedidos cancelados
-- sejam tratados adequadamente nas análises de receita e faturamento.



-- =====================================================
-- 4.4.3 ORDER PAYMENTS - PARCELAS IGUAIS A ZERO
-- Investigar pagamentos com cartão e quantidade de parcelas igual a zero
-- =====================================================
SELECT olist_order_payments_dataset.order_id,
olist_orders_dataset.order_status,
olist_order_payments_dataset.payment_sequential,
olist_order_payments_dataset.payment_type,
olist_order_payments_dataset.payment_installments,
olist_order_payments_dataset.payment_value
FROM staging.olist_order_payments_dataset
JOIN staging.olist_orders_dataset
ON olist_order_payments_dataset.order_id = olist_orders_dataset.order_id
WHERE olist_order_payments_dataset.payment_installments = 0;


-- Conclusão:
-- Foram identificados 2 pagamentos com payment_installments igual a zero.
-- Ambos são pagamentos por credit_card, possuem valor positivo
-- e pertencem a pedidos com status delivered.
-- Portanto, os pagamentos foram efetivamente registrados e os pedidos concluídos.
-- A inconsistência está concentrada no campo payment_installments,
-- que apresenta valor zero em pagamentos com cartão de crédito.
-- Esses registros devem ser tratados com cautela antes de análises
-- relacionadas à quantidade de parcelas.


-- =====================================================
-- 4.4.3.1 ORDER PAYMENTS - CONTEXTO DOS PAGAMENTOS COM ZERO PARCELAS
-- Verificar todos os pagamentos dos pedidos identificados
-- =====================================================
SELECT order_id, payment_sequential, payment_type, payment_installments, payment_value
FROM staging.olist_order_payments_dataset
WHERE order_id IN ('1a57108394169c0b47d8f876acc9ba2d','744bade1fcf9ff3f31d860ace076d422')
ORDER BY order_id, payment_sequential;

-- Conclusão:
-- Ao analisar todos os pagamentos dos 2 pedidos com payment_installments igual a zero,
-- foi encontrado apenas 1 registro de pagamento para cada pedido.
-- Em ambos os casos, payment_sequential é igual a 2,
-- sem registro correspondente com payment_sequential igual a 1.
-- Portanto, além da quantidade de parcelas igual a zero,
-- os registros apresentam uma sequência de pagamento iniciada em 2.
-- O resultado reforça a existência de inconsistências pontuais nesses pagamentos.


-- =====================================================
-- 4.4.3.2 ORDER PAYMENTS - SEQUÊNCIA INICIAL DOS PAGAMENTOS
-- Verificar pedidos cuja sequência de pagamento não começa em 1
-- =====================================================
SELECT order_id,
MIN(payment_sequential) AS primeira_sequencia,
COUNT(*) AS total_pagamentos
FROM staging.olist_order_payments_dataset
GROUP BY order_id
HAVING MIN(payment_sequential) > 1
ORDER BY primeira_sequencia, order_id;


-- Conclusão:
-- Foram identificados 80 pedidos cuja sequência de pagamento
-- não se inicia em 1.
-- Em todos os casos, a menor payment_sequential encontrada é 2.
-- Desses pedidos, 78 possuem apenas 1 registro de pagamento
-- e 2 possuem 2 registros de pagamento.
-- Portanto, a ausência da sequência 1 não é exclusiva dos 2 casos
-- com payment_installments igual a zero, indicando um padrão mais amplo
-- de inconsistência na numeração sequencial dos pagamentos.


-- =====================================================
-- 4.5 ORDER REVIEWS - QUALIDADE DAS AVALIAÇÕES
-- Verificar campos ausentes e notas potencialmente inválidas
-- =====================================================
SELECT COUNT(*) AS total_avaliacoes,
COUNT(*) FILTER (WHERE review_id IS NULL) AS review_id_ausente,
COUNT(*) FILTER (WHERE order_id IS NULL) AS order_id_ausente,
COUNT(*) FILTER (WHERE review_score IS NULL) AS nota_ausente,
COUNT(*) FILTER (WHERE review_score < 1 OR review_score > 5) AS nota_invalida,
COUNT(*) FILTER (WHERE NULLIF(TRIM(review_comment_title), '') IS NULL) AS titulo_ausente,
COUNT(*) FILTER (WHERE NULLIF(TRIM(review_comment_message), '') IS NULL) AS comentario_ausente,
COUNT(*) FILTER (WHERE review_creation_date IS NULL) AS data_criacao_ausente,
COUNT(*) FILTER (WHERE review_answer_timestamp IS NULL) AS data_resposta_ausente
FROM staging.olist_order_reviews_dataset;


-- Conclusão:
-- Os 99.224 registros de avaliação possuem review_id, order_id,
-- review_score, review_creation_date e review_answer_timestamp preenchidos.
-- Também não foram identificadas notas fora da faixa esperada de 1 a 5.
-- Foram encontrados 87.658 registros sem título e 58.256 sem comentário.
-- Essas ausências não são necessariamente inconsistências, pois campos textuais
-- de avaliação podem ser opcionais.
-- Portanto, a qualidade dos campos estruturais de order_reviews é satisfatória.


-- =====================================================
-- 4.5.1 ORDER REVIEWS - MÚLTIPLAS AVALIAÇÕES POR PEDIDO
-- Verificar pedidos com mais de uma avaliação
-- =====================================================
SELECT order_id,
COUNT(*) AS total_avaliacoes
FROM staging.olist_order_reviews_dataset
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY total_avaliacoes DESC, order_id;


-- Conclusão:
-- Foram identificados 547 pedidos com mais de uma avaliação.
-- Desses, 543 possuem 2 avaliações e 4 possuem 3 avaliações.
-- Portanto, order_id não representa uma relação de uma única avaliação
-- por pedido dentro de order_reviews.
-- Esse comportamento deve ser considerado em análises que utilizem
-- review_score, pois um mesmo pedido pode contribuir com mais de uma avaliação.


-- =====================================================
-- 4.5.1.1 ORDER REVIEWS - RESUMO DE AVALIAÇÕES POR PEDIDO
-- Consolidar pedidos que possuem múltiplas avaliações
-- =====================================================
SELECT total_avaliacoes,
COUNT(*) AS total_pedidos
FROM (
SELECT order_id,
COUNT(*) AS total_avaliacoes
FROM staging.olist_order_reviews_dataset
GROUP BY order_id
HAVING COUNT(*) > 1
) AS pedidos_com_multiplas_avaliacoes
GROUP BY total_avaliacoes
ORDER BY total_avaliacoes;

-- Conclusão:
-- Foram identificados 547 pedidos com múltiplas avaliações.
-- 543 pedidos possuem 2 avaliações e 4 pedidos possuem 3 avaliações.
-- Portanto, a relação entre order_id e avaliações não é de 1 para 1.
-- Essa característica deverá ser considerada nas análises de satisfação
-- para evitar que pedidos com múltiplas avaliações tenham peso indevido.


-- =====================================================
-- 4.5.2 ORDER REVIEWS - DIVERGÊNCIA DE NOTAS POR PEDIDO
-- Verificar se pedidos com múltiplas avaliações possuem notas diferentes
-- =====================================================
SELECT COUNT(*) AS pedidos_multiplas_avaliacoes,
COUNT(*) FILTER (WHERE notas_distintas = 1) AS pedidos_mesma_nota,
COUNT(*) FILTER (WHERE notas_distintas > 1) AS pedidos_notas_diferentes
FROM (
SELECT order_id,
COUNT(*) AS total_avaliacoes,
COUNT(DISTINCT review_score) AS notas_distintas
FROM staging.olist_order_reviews_dataset
GROUP BY order_id
HAVING COUNT(*) > 1
) AS resumo_avaliacoes;

-- Conclusão:
-- Foram identificados 547 pedidos com múltiplas avaliações.
-- Em 345 pedidos, todas as avaliações possuem a mesma nota.
-- Em 202 pedidos, existem avaliações com notas diferentes para o mesmo order_id.
-- Portanto, múltiplas avaliações não podem ser tratadas automaticamente
-- como simples duplicidades.
-- Nas análises de satisfação será necessário definir uma regra de consolidação
-- por pedido para evitar duplicidade e distorção dos indicadores.

-- =====================================================
-- 4.6 ORDER ITEMS - QUALIDADE DOS ITENS
-- Verificar campos ausentes e valores potencialmente inválidos
-- =====================================================
SELECT COUNT(*) AS total_itens,
COUNT(*) FILTER (WHERE order_id IS NULL) AS order_id_ausente,
COUNT(*) FILTER (WHERE order_item_id IS NULL) AS item_id_ausente,
COUNT(*) FILTER (WHERE product_id IS NULL) AS product_id_ausente,
COUNT(*) FILTER (WHERE seller_id IS NULL) AS seller_id_ausente,
COUNT(*) FILTER (WHERE shipping_limit_date IS NULL) AS data_limite_envio_ausente,
COUNT(*) FILTER (WHERE price IS NULL) AS preco_ausente,
COUNT(*) FILTER (WHERE freight_value IS NULL) AS frete_ausente,
COUNT(*) FILTER (WHERE price <= 0) AS preco_nao_positivo,
COUNT(*) FILTER (WHERE freight_value < 0) AS frete_negativo
FROM staging.olist_order_items_dataset;

-- Conclusão:
-- Os 112.650 registros de order_items possuem todos os campos
-- estruturais e financeiros analisados preenchidos.
-- Não foram identificados preços iguais ou inferiores a zero
-- nem valores de frete negativos.
-- Portanto, não foram encontradas inconsistências nesses critérios
-- de qualidade dos itens dos pedidos.


-- =====================================================
-- 4.6.1 ORDER ITEMS - CONSISTÊNCIA DA DATA LIMITE DE ENVIO
-- Verificar itens com shipping_limit_date anterior à compra
-- =====================================================
SELECT COUNT(*) AS itens_data_limite_invalida
FROM staging.olist_order_items_dataset
JOIN staging.olist_orders_dataset
ON olist_order_items_dataset.order_id = olist_orders_dataset.order_id
WHERE olist_order_items_dataset.shipping_limit_date < olist_orders_dataset.order_purchase_timestamp;


-- Conclusão:
-- Não foram identificados itens com shipping_limit_date
-- anterior à data de compra do pedido.
-- Portanto, não foram encontradas inconsistências cronológicas
-- nesse campo.
-- A tabela order_items apresenta boa consistência nos critérios analisados.

-- =====================================================
-- 4.7 CUSTOMERS - QUALIDADE DOS CLIENTES
-- Verificar campos cadastrais ausentes
-- =====================================================
SELECT COUNT(*) AS total_clientes,
COUNT(*) FILTER (WHERE customer_id IS NULL) AS customer_id_ausente,
COUNT(*) FILTER (WHERE customer_unique_id IS NULL) AS unique_id_ausente,
COUNT(*) FILTER (WHERE customer_zip_code_prefix IS NULL) AS cep_ausente,
COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_city), '') IS NULL) AS cidade_ausente,
COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_state), '') IS NULL) AS estado_ausente
FROM staging.olist_customers_dataset;


-- Conclusão:
-- Os 99.441 registros de customers possuem todos os campos
-- cadastrais analisados preenchidos.
-- Não foram identificados valores ausentes em customer_id,
-- customer_unique_id, customer_zip_code_prefix,
-- customer_city ou customer_state.
-- Portanto, a tabela customers apresenta boa completude
-- nos atributos cadastrais avaliados.

-- =====================================================
-- 4.7.1 CUSTOMERS - CLIENTES RECORRENTES
-- Verificar customer_unique_id associados a mais de um customer_id
-- =====================================================
SELECT customer_unique_id,
COUNT(*) AS total_customer_ids
FROM staging.olist_customers_dataset
GROUP BY customer_unique_id
HAVING COUNT(*) > 1
ORDER BY total_customer_ids DESC, customer_unique_id;

-- =====================================================
-- 4.7.1.1 CUSTOMERS - RESUMO DE RECORRÊNCIA
-- Consolidar clientes pela quantidade de customer_ids
-- =====================================================
SELECT total_customer_ids,
COUNT(*) AS total_clientes
FROM (
SELECT customer_unique_id,
COUNT(*) AS total_customer_ids
FROM staging.olist_customers_dataset
GROUP BY customer_unique_id
HAVING COUNT(*) > 1
) AS clientes_recorrentes
GROUP BY total_customer_ids
ORDER BY total_customer_ids;


-- Conclusão:
-- Foram identificados 2.997 customer_unique_id associados
-- a mais de um customer_id.
-- A maior parte dos clientes recorrentes possui 2 customer_ids,
-- totalizando 2.745 clientes nessa condição.
-- O maior número identificado foi de 17 customer_ids associados
-- ao mesmo customer_unique_id.
-- Esse comportamento não representa uma duplicidade indevida.
-- Ele indica que customer_unique_id deverá ser utilizado para identificar
-- o cliente ao analisar recorrência, recompra e comportamento ao longo do tempo.

-- =====================================================
-- 4.8 SELLERS - QUALIDADE DOS VENDEDORES
-- Verificar campos cadastrais ausentes
-- =====================================================
SELECT COUNT(*) AS total_vendedores,
COUNT(*) FILTER (WHERE seller_id IS NULL) AS seller_id_ausente,
COUNT(*) FILTER (WHERE seller_zip_code_prefix IS NULL) AS cep_ausente,
COUNT(*) FILTER (WHERE NULLIF(TRIM(seller_city), '') IS NULL) AS cidade_ausente,
COUNT(*) FILTER (WHERE NULLIF(TRIM(seller_state), '') IS NULL) AS estado_ausente
FROM staging.olist_sellers_dataset;

-- Conclusão:
-- Os 3.095 registros de sellers possuem todos os campos
-- cadastrais analisados preenchidos.
-- Não foram identificados valores ausentes em seller_id,
-- seller_zip_code_prefix, seller_city ou seller_state.
-- Portanto, a tabela sellers apresenta boa completude
-- nos atributos cadastrais avaliados.

-- =====================================================
-- 4.9 GEOLOCATION - QUALIDADE DOS DADOS GEOGRÁFICOS
-- Verificar campos ausentes e coordenadas potencialmente inválidas
-- =====================================================
SELECT COUNT(*) AS total_registros,
COUNT(*) FILTER (WHERE geolocation_zip_code_prefix IS NULL) AS cep_ausente,
COUNT(*) FILTER (WHERE geolocation_lat IS NULL) AS latitude_ausente,
COUNT(*) FILTER (WHERE geolocation_lng IS NULL) AS longitude_ausente,
COUNT(*) FILTER (WHERE NULLIF(TRIM(geolocation_city), '') IS NULL) AS cidade_ausente,
COUNT(*) FILTER (WHERE NULLIF(TRIM(geolocation_state), '') IS NULL) AS estado_ausente,
COUNT(*) FILTER (WHERE geolocation_lat < -90 OR geolocation_lat > 90) AS latitude_invalida,
COUNT(*) FILTER (WHERE geolocation_lng < -180 OR geolocation_lng > 180) AS longitude_invalida
FROM staging.olist_geolocation_dataset;


-- Conclusão:
-- Os 1.000.163 registros de geolocation possuem todos os campos
-- geográficos analisados preenchidos.
-- Não foram identificadas latitudes fora do intervalo -90 a 90
-- nem longitudes fora do intervalo -180 a 180.
-- Portanto, a tabela apresenta boa completude e validade básica
-- das coordenadas geográficas.

-- =====================================================
-- 4.9.1 GEOLOCATION - REGISTROS DUPLICADOS
-- Verificar linhas geográficas completamente repetidas
-- =====================================================
SELECT COUNT(*) AS grupos_duplicados,
SUM(total_repeticoes - 1) AS registros_duplicados_excedentes
FROM (
SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state, COUNT(*) AS total_repeticoes
FROM staging.olist_geolocation_dataset
GROUP BY geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state
HAVING COUNT(*) > 1
) AS duplicidades;



-- Conclusão:
-- Foram identificados 128.174 grupos de registros geográficos
-- com duplicidade exata considerando CEP, latitude, longitude,
-- cidade e estado.
-- Esses grupos representam 261.831 registros excedentes,
-- que poderiam ser removidos mantendo apenas uma ocorrência
-- de cada combinação geográfica idêntica.
-- Após a remoção das duplicidades exatas, permaneceriam
-- 738.332 combinações geográficas distintas.
-- Portanto, a tabela geolocation necessita de deduplicação
-- antes de ser utilizada na camada tratada/modelada.


-- =====================================================
-- 4.9.2 GEOLOCATION - FREQUÊNCIA DAS DUPLICIDADES
-- Verificar quantidade máxima de repetições de uma combinação geográfica
-- =====================================================
SELECT MAX(total_repeticoes) AS maior_repeticao,
AVG(total_repeticoes) AS media_repeticoes
FROM (
SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state, COUNT(*) AS total_repeticoes
FROM staging.olist_geolocation_dataset
GROUP BY geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state
HAVING COUNT(*) > 1
) AS duplicidades;

-- Conclusão:
-- Entre os grupos com duplicidade exata, cada combinação geográfica
-- aparece em média aproximadamente 3 vezes.
-- A maior duplicidade identificada corresponde a uma mesma combinação
-- de CEP, latitude, longitude, cidade e estado repetida 314 vezes.
-- Portanto, existem casos de repetição significativa na tabela geolocation,
-- reforçando a necessidade de deduplicação na camada tratada/modelada.


-- =====================================================
-- 4.9.2.1 GEOLOCATION - MAIOR DUPLICIDADE
-- Identificar a combinação geográfica com maior repetição
-- =====================================================
SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state, COUNT(*) AS total_repeticoes
FROM staging.olist_geolocation_dataset
GROUP BY geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state
ORDER BY total_repeticoes DESC
LIMIT 10;



-- Conclusão:
-- As maiores duplicidades exatas da tabela geolocation apresentam
-- volumes elevados de repetição.
-- O maior caso identificado corresponde ao CEP 88220, em Itapema/SC,
-- com a mesma combinação de latitude, longitude, cidade e estado
-- repetida 314 vezes.
-- Também foram encontrados outros casos com mais de 100 repetições,
-- como Barueri/SP, São Paulo/SP e Rio de Janeiro/RJ.
-- Esses resultados reforçam que a duplicidade não é pontual
-- e que a deduplicação deverá fazer parte da camada tratada/modelada.


-- =====================================================
-- 4.10 PRODUCT CATEGORY TRANSLATION - QUALIDADE DOS DADOS
-- Verificar campos ausentes e duplicidades
-- =====================================================
SELECT COUNT(*) AS total_categorias,
COUNT(*) FILTER (WHERE NULLIF(TRIM(product_category_name), '') IS NULL) AS categoria_origem_ausente,
COUNT(*) FILTER (WHERE NULLIF(TRIM(product_category_name_english), '') IS NULL) AS categoria_ingles_ausente,
COUNT(DISTINCT product_category_name) AS categorias_origem_unicas,
COUNT(DISTINCT product_category_name_english) AS categorias_ingles_unicas
FROM staging.product_category_name_translation;


-- =====================================================
-- 4.10.1 PRODUCT CATEGORY TRANSLATION - DUPLICIDADES
-- Verificar categorias repetidas na tabela de tradução
-- =====================================================
SELECT product_category_name,
COUNT(*) AS total_repeticoes
FROM staging.product_category_name_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1
ORDER BY total_repeticoes DESC, product_category_name;


-- Conclusão:
-- A tabela product_category_name_translation possui 71 registros,
-- todos com categoria de origem e tradução para inglês preenchidas.
-- As 71 categorias de origem são únicas e as 71 traduções também são únicas.
-- Não foram identificadas duplicidades na tabela.
-- Portanto, a tabela apresenta boa qualidade interna.
-- As categorias de products sem correspondência identificadas anteriormente
-- representam uma questão de cobertura da tabela de tradução,
-- e não duplicidade ou ausência de dados nesta tabela.




































