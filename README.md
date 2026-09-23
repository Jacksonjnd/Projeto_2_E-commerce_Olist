# Análise de E-commerce Olist com SQL

## Sobre o projeto

Este projeto apresenta uma análise do dataset público da Olist, marketplace brasileiro de e-commerce, utilizando SQL para explorar, validar, relacionar e preparar os dados para análises de negócio.

Meu objetivo foi desenvolver uma análise estruturada, seguindo uma linha de raciocínio clara desde a compreensão dos dados brutos até a construção de uma camada analítica preparada para análises posteriores.

Um dos principais cuidados durante o desenvolvimento foi fazer com que o código pudesse ser entendido não apenas por quem o escreveu, mas também por qualquer outra pessoa que tenha acesso ao projeto. Por isso, as queries foram acompanhadas de comentários, legendas, objetivo da análise, explicação do raciocínio e interpretação dos resultados.

*Também fiz uma escolha consciente de não utilizar aliases curtos para os nomes das tabelas*. Como o projeto envolve várias tabelas e diversos relacionamentos, preferi manter os nomes completos para facilitar a identificação da origem de cada campo e preservar o lastro das informações durante a leitura das queries. Aliases são amplamente utilizados em SQL e podem ser muito úteis, mas, neste projeto, priorizei clareza, rastreabilidade e facilidade de entendimento.

Outro ponto importante é que cada análise foi acompanhada de uma conclusão, para que o resultado não ficasse restrito apenas ao código ou à tabela retornada. A intenção é que qualquer pessoa que consulte o portfólio consiga entender o que foi analisado, por que aquela análise foi realizada e o que o resultado representa, mesmo sem acompanhar toda a construção técnica.

---

## Objetivo

O projeto foi desenvolvido com alguns objetivos principais:

* compreender a estrutura do banco de dados da Olist;
* validar a qualidade e consistência dos dados;
* entender os relacionamentos entre as tabelas;
* identificar corretamente a granularidade de cada base;
* validar chaves primárias e relacionamentos;
* preparar os dados para análises de negócio;
* construir indicadores relacionados a pedidos e logística;
* criar uma camada analítica reutilizável;
* documentar o raciocínio utilizado em cada etapa;
* transformar resultados técnicos em conclusões compreensíveis.

---

## Dataset

A base utilizada possui informações sobre diferentes etapas da operação de um e-commerce.

Entre os dados analisados estão:

* clientes;
* pedidos;
* itens dos pedidos;
* produtos;
* vendedores;
* pagamentos;
* avaliações dos clientes;
* localização geográfica;
* categorias de produtos.

No total, o dataset possui desde tabelas com alguns milhares de registros até a base de geolocalização, com aproximadamente **1 milhão de linhas**.

Essa estrutura permite trabalhar com um cenário de alta complexidade na análise de dados, no qual diferentes fontes precisam ser compreendidas e relacionadas antes de qualquer conclusão.

---

## 1. Importação e validação dos dados

A primeira etapa foi entender a estrutura dos arquivos antes de iniciar as análises.

Foram avaliados:

* quantidade de registros;
* nomes das colunas;
* tipos de dados;
* possíveis chaves primárias;
* chaves de relacionamento;
* campos nulos;
* duplicidades;
* granularidade das tabelas;
* consistência dos arquivos importados.

Essa etapa é importante porque uma análise pode produzir um resultado aparentemente correto mesmo quando existem problemas na origem dos dados.

Por isso, antes de analisar indicadores, foi necessário entender **o que cada linha de cada tabela representa**.

---

## 2. Tratamento de problemas encontrados na base

Durante a importação também foram identificados problemas que precisaram ser investigados.

Um exemplo ocorreu na base de avaliações dos clientes.

O arquivo possuía comentários com **quebras de linha dentro dos próprios textos**, o que interferia na importação do CSV.

Em vez de simplesmente alterar ou excluir esses registros, o problema foi investigado até identificar sua origem e ajustar corretamente a configuração de importação.

Esse tipo de validação faz parte do trabalho de análise de dados: nem sempre o problema está na query. Muitas vezes é necessário investigar a estrutura, o arquivo de origem ou a forma como os dados foram armazenados.

---

## 3. Validação dos relacionamentos

Também foram analisadas as relações entre as tabelas.

Entre os principais identificadores estudados estão:

`order_id`

Identifica o pedido e permite relacionar diferentes informações da operação.

`customer_id`

Identifica o cliente associado especificamente a determinado pedido.

`customer_unique_id`

Permite identificar um mesmo consumidor ao longo de diferentes compras.

`product_id`

Relaciona os itens vendidos aos produtos.

`seller_id`

Relaciona os itens aos vendedores responsáveis pela venda.

Essa diferenciação é importante porque campos aparentemente semelhantes podem representar conceitos diferentes.

Um exemplo é a diferença entre `customer_id` e `customer_unique_id`.

Entender essa estrutura evita erros em análises como **quantidade de clientes, recorrência de compra e comportamento do consumidor**.

---

## 4. Granularidade dos dados

Um dos pontos trabalhados com bastante atenção foi a **granularidade**.

Antes de realizar um `JOIN`, é importante saber exatamente o que cada linha representa.

Por exemplo:

* uma linha por pedido;
* uma linha por item do pedido;
* uma linha por pagamento;
* uma linha por avaliação.

Essa distinção é fundamental porque relacionar tabelas com granularidades diferentes sem preparação pode causar **multiplicação de registros**.

Como consequência, métricas como receita, quantidade de pedidos ou valor pago podem ser calculadas incorretamente.

Por isso, pagamentos e avaliações foram consolidados antes de serem relacionados à camada principal de pedidos.

---

## 5. Regras de negócio

Também foram definidas regras explícitas para as análises.

Uma delas foi a definição de **pedido válido**.

Neste projeto:

`pedido_valido = order_status diferente de 'canceled' e 'unavailable'`

Os pedidos cancelados ou indisponíveis não foram simplesmente excluídos da base.

Eles foram preservados para permitir análises específicas sobre esses status, enquanto a regra de pedido válido pode ser utilizada quando o indicador exigir.

Essa separação evita alterar silenciosamente os dados e deixa claro qual regra está sendo utilizada em cada análise.

---

## 6. Indicadores logísticos

A análise também preparou indicadores relacionados ao processo de entrega.

Entre eles:

* dias para entrega;
* diferença entre entrega realizada e prazo estimado;
* quantidade de dias de atraso;
* identificação de pedidos entregues dentro do prazo.

Esses indicadores permitem transformar datas isoladas em informações mais úteis para avaliar a operação logística.

---

## 7. Camada analítica

Após compreender e validar os dados, foram construídas **views analíticas reutilizáveis**.

Entre elas:

* `vw_orders_base`
* `vw_order_items_base`
* `vw_payments_order`
* `vw_reviews_order`
* `vw_orders_analytics`
* `vw_customers_analytics`
* `vw_products_analytics`
* `vw_sellers_analytics`
* `vw_categories_analytics`
* `vw_geolocation_zip`
* `dim_calendar`

A `vw_orders_analytics` concentra informações no nível de pedido e funciona como uma das principais bases para análises posteriores.

Já a `vw_order_items_base` mantém a granularidade necessária para análises relacionadas a produtos, categorias e vendedores.

Essa separação permite escolher a fonte correta dependendo da pergunta de negócio que precisa ser respondida.

---

# Documentação das queries

Um cuidado importante neste projeto foi **não deixar queries soltas no código**.

Sempre que possível, cada bloco contém informações como:

* o que será analisado;
* por que aquela análise está sendo realizada;
* qual tabela está sendo utilizada;
* qual é a granularidade esperada;
* qual regra está sendo aplicada;
* o que determinada função ou transformação representa;
* como interpretar o resultado;
* conclusão obtida após a execução.

Exemplo da lógica utilizada:

```sql
-- OBJETIVO:
-- Identificar o comportamento dos pedidos em relação ao prazo de entrega.

-- RACIOCÍNIO:
-- Comparar a data real de entrega com a data estimada para identificar
-- pedidos entregues antecipadamente, dentro do prazo ou com atraso.

-- RESULTADO:
-- A consulta permite medir o desempenho logístico dos pedidos.
```

A intenção dessa documentação é tornar o código **legível, auditável e reutilizável**.

Uma análise não deveria depender da memória de quem escreveu o código para ser compreendida.

Se outra pessoa abrir o projeto meses depois, deve conseguir entender:

**o que foi feito, por que foi feito e o que aquele resultado significa.**

---

## Escolha consciente pelo uso dos nomes completos das tabelas

Outra decisão adotada no projeto foi **não utilizar aliases curtos para identificar as tabelas nas queries**.

Essa foi uma escolha pessoal de legibilidade.

Como o projeto trabalha com várias tabelas relacionadas, preferi manter os nomes completos para preservar com mais facilidade o **lastro da informação**, deixando explícito de onde cada campo está sendo obtido.

Em uma consulta com muitos `JOINs`, aliases como `o`, `c`, `p`, `i` ou `s` podem reduzir o tamanho do código, mas também podem aumentar a necessidade de lembrar constantemente o significado de cada abreviação.

Neste projeto, priorizei uma leitura como:

```sql
orders.order_id
customers.customer_unique_id
order_items.product_id
payments.payment_value
```

em vez de:

```sql
o.order_id
c.customer_unique_id
i.product_id
p.payment_value
```

Não se trata de considerar aliases incorretos. Eles são amplamente utilizados em SQL e podem ser úteis em diversos contextos.

Aqui, a decisão foi priorizar **clareza, rastreabilidade e facilidade de leitura**, especialmente por se tratar de um projeto de portfólio com muitas tabelas e relacionamentos.

Para mim, ao revisar uma query, deve ser possível identificar rapidamente **qual tabela originou cada informação**, sem depender da interpretação prévia de abreviações.

---

# Conclusões junto às análises

Outro princípio adotado no projeto foi não encerrar uma análise apenas apresentando uma tabela de resultados.

Sempre que uma análise é realizada, procuro registrar também sua **interpretação ou conclusão**.

A query responde tecnicamente à pergunta.

A conclusão explica **o que aquele resultado está mostrando**.

Essa separação é importante porque, em um ambiente profissional, nem todas as pessoas que utilizam uma análise precisam conhecer SQL.

Um gestor, profissional de negócio ou outro analista deve conseguir compreender o resultado sem precisar interpretar sozinho todo o código utilizado para chegar até ele.

---

## Boas práticas aplicadas

Durante o desenvolvimento procurei aplicar alguns princípios que considero importantes em projetos de dados:

**Clareza antes da complexidade**

Uma query deve ser compreensível. Complexidade técnica só faz sentido quando necessária para resolver o problema.

**Rastreabilidade das informações**

Optei por utilizar os nomes completos das tabelas em vez de aliases curtos para facilitar a identificação da origem de cada campo, principalmente nas consultas com vários relacionamentos.

**Granularidade definida**

Antes de relacionar tabelas, é necessário entender o que cada linha representa.

**Validação antes da análise**

Antes de confiar em um indicador, é necessário validar a estrutura e a qualidade dos dados utilizados para calculá-lo.

**Regras de negócio explícitas**

Critérios como "pedido válido" devem estar documentados e não escondidos dentro da lógica da consulta.

**Preservação dos dados originais**

Inconsistências encontradas não devem ser corrigidas silenciosamente. Primeiro precisam ser identificadas, documentadas e compreendidas.

**Código documentado**

Comentários ajudam outras pessoas a entenderem a finalidade e a lógica da análise.

**Conclusão após a consulta**

Executar uma query é apenas uma etapa. O trabalho do analista também envolve interpretar o resultado e comunicar o que ele representa.

---

## Linha de raciocínio do projeto

De forma resumida, o projeto seguiu esta sequência:

**Dados brutos → validação → entendimento da granularidade → relacionamentos → regras de negócio → transformação → indicadores → camada analítica → interpretação**

Essa estrutura foi utilizada para evitar começar diretamente pelas métricas sem antes compreender a origem dos dados.

---

## Tecnologias utilizadas

* SQL
* PostgreSQL
* DBeaver
* Git
* GitHub

---

## Aprendizados

Este projeto reforçou que trabalhar com dados envolve muito mais do que escrever consultas.

Foi necessário entender a estrutura das bases, investigar problemas de importação, validar relacionamentos, definir granularidades, evitar duplicações causadas por `JOINs`, estabelecer regras analíticas e preparar informações para consumo posterior.

Também reforçou um princípio que considero importante para qualquer projeto de análise:

> **Uma boa análise precisa ser tecnicamente correta, mas também precisa ser compreensível para quem não participou da sua construção.**

Por isso, além das queries, o projeto registra o raciocínio utilizado, a origem das informações e as conclusões encontradas ao longo das análises.

O objetivo é que o repositório não seja apenas uma coleção de códigos SQL, mas um registro completo do processo de análise.
