/*Todas as consultas estão com título + descrição do objetivo/enunciado da consulta*/
/*================================================================================*/

/*1º CONSULTA: Acompanhamento de Beneficiário: Histórico de Pagamentos em 2024 e 
Verificação de Retroativos para uma Pessoa de Uberlândia */

SELECT
    p.nome AS "Nome do Beneficiário",
    pg.valor_parcela AS "Valor da Parcela",
    CASE
        WHEN EXTRACT(YEAR FROM pg.mes_referencia) = 2024 THEN 'Sim'
        ELSE 'Não'
    END AS "Pagamento de 2024",
    TO_CHAR(pg.mes_referencia, 'MM-YYYY') AS "Mês de Referência",
    CASE
        WHEN EXTRACT(YEAR FROM pg.mes_referencia) = 2023 AND EXTRACT(YEAR FROM pg.mes_competencia) = 2024 THEN 'Sim'
        ELSE 'Não'
    END AS "Recebeu Retroativo",
    CASE        WHEN EXTRACT(YEAR FROM pg.mes_referencia) = 2023 AND EXTRACT(YEAR FROM pg.mes_competencia) = 2024 THEN TO_CHAR(pg.mes_referencia, 'MM-YYYY')
        ELSE NULL
    END AS "Mês do Retroativo"
FROM
    pagamentos pg
JOIN
    pessoa p ON pg.pessoa_nis = p.nis
JOIN
    municipios m ON pg.municipio_siafi = m.codigo_siafi
WHERE
    p.nis = 16142837799 AND m.codigo_siafi = 5403
-- A linha abaixo garante a ordenação cronológica correta pela data original
ORDER BY
    pg.mes_referencia ASC;
/*================================================================================*/

/*2º CONSULTA: Análise de Desigualdade na Distribuição de Recursos: Concentração 
Percentual e Acumulada do Bolsa Família nos Estados Brasileiros em 2024.*/

WITH StatsPorUF AS (
    -- Calcular as métricas base para cada estado (UF)
    SELECT
        m.uf,
        SUM(p.valor_parcela) AS valor_total_uf,
        COUNT(DISTINCT p.pessoa_nis) AS qtd_beneficiarios_uf,
        COUNT(DISTINCT m.codigo_siafi) AS qtd_municipios_uf
    FROM
        pagamentos AS p
    JOIN
        municipios AS m ON p.municipio_siafi = m.codigo_siafi
    WHERE
        EXTRACT(YEAR FROM p.mes_referencia) = 2024
    GROUP BY
        m.uf
),
CalculosGerais AS (
    -- Calcular os percentuais e as médias
    SELECT
        uf,
        valor_total_uf,
        qtd_beneficiarios_uf,
        qtd_municipios_uf,
        -- Percentual que cada estado representa do total geral
        (valor_total_uf / SUM(valor_total_uf) OVER ()) * 100 AS percentual_do_total,
        -- Valor médio por beneficiário no estado
        valor_total_uf / qtd_beneficiarios_uf AS valor_medio_por_beneficiario,
        -- Valor médio por município no estado
        valor_total_uf / qtd_municipios_uf AS valor_medio_por_municipio
    FROM
        StatsPorUF
)
-- Calcular o percentual acumulado (Princípio de Pareto)
SELECT
    uf,
    valor_total_uf,
    percentual_do_total,
    -- Soma o percentual da linha atual com a soma de todos os percentuais das linhas anteriores
    SUM(percentual_do_total) OVER (ORDER BY percentual_do_total DESC) AS percentual_acumulado,
    valor_medio_por_beneficiario,
    valor_medio_por_municipio
FROM
    CalculosGerais
ORDER BY
    percentual_do_total DESC;
/*================================================================================*/

/*3º CONSULTA: Análise Comparativa da Dinâmica do Bolsa Família: Variação Percentual 
Mensal de Beneficiários em Uberlândia versus a Média das Cidades de Minas Gerais (2024).*/

WITH UdiData AS (
    -- Calcular os totais mensais apenas para Uberlândia
    SELECT
        TO_CHAR(mes_referencia, 'YYYY-MM') AS mes,
        SUM(valor_parcela) AS valor_total_udi,
        COUNT(DISTINCT pessoa_nis) AS qtd_pessoas_udi
    FROM pagamentos p
    JOIN municipios m ON p.municipio_siafi = m.codigo_siafi
    WHERE m.nome = 'UBERLANDIA' AND m.uf = 'MG' AND EXTRACT(YEAR FROM p.mes_referencia) = 2024
    GROUP BY mes
),
MGData AS (
    -- Calcular a média mensal para as cidades de MG
    SELECT
        mes, -- <-- ESTA É A LINHA QUE FOI CORRIGIDA
        AVG(valor_total_por_cidade) AS media_valor_total_mg,
        AVG(qtd_pessoas_por_cidade) AS media_qtd_pessoas_mg
    FROM (
        SELECT
            p.municipio_siafi,
            TO_CHAR(p.mes_referencia, 'YYYY-MM') AS mes,
            SUM(p.valor_parcela) as valor_total_por_cidade,
            COUNT(DISTINCT p.pessoa_nis) as qtd_pessoas_por_cidade
        FROM pagamentos p
        JOIN municipios m ON p.municipio_siafi = m.codigo_siafi
        WHERE m.uf = 'MG' AND EXTRACT(YEAR FROM p.mes_referencia) = 2024
        GROUP BY p.municipio_siafi, mes
    ) AS stats_cidades_mg
    GROUP BY mes
)
-- juntar os dados de Uberlândia e da média de MG para comparar
SELECT
    u.mes,
    u.qtd_pessoas_udi,
    ROUND(m.media_qtd_pessoas_mg, 0) AS media_pessoas_cidades_mg,
    -- Cálculo da variação percentual de Uberlândia em relação ao mês anterior
    ROUND(
        ( (u.qtd_pessoas_udi - LAG(u.qtd_pessoas_udi, 1, u.qtd_pessoas_udi) OVER (ORDER BY u.mes)) * 100.0 )
        / LAG(u.qtd_pessoas_udi, 1, u.qtd_pessoas_udi) OVER (ORDER BY u.mes), 2
    ) AS variacao_pct_udi,
    -- Cálculo da variação percentual da média das cidades de MG em relação ao mês anterior
    ROUND(
        ( (m.media_qtd_pessoas_mg - LAG(m.media_qtd_pessoas_mg, 1, m.media_qtd_pessoas_mg) OVER (ORDER BY u.mes)) * 100.0 )
        / LAG(m.media_qtd_pessoas_mg, 1, m.media_qtd_pessoas_mg) OVER (ORDER BY u.mes), 2
    ) AS variacao_pct_media_mg
FROM
    UdiData u
JOIN
    MGData m ON u.mes = m.mes
ORDER BY
    u.mes;
/*================================================================================*/

/*4º CONSULTA: Análise Percentual da Dependência Contínua do Bolsa Família em Uberlândia (1º Semestre de 2024).*/

WITH BeneficiariosContinuos AS (
    -- Identificar o NIS de todos que receberam por 6 meses em Uberlândia
    SELECT
        p.pessoa_nis
    FROM
        pagamentos p
    JOIN
        municipios m ON p.municipio_siafi = m.codigo_siafi
    WHERE
        m.nome = 'UBERLANDIA' AND m.uf = 'MG'
        AND EXTRACT(YEAR FROM p.mes_referencia) = 2024
    GROUP BY
        p.pessoa_nis
    HAVING
        COUNT(DISTINCT DATE_TRUNC('month', p.mes_referencia)) = 6
),
TotalBeneficiarios AS (
    -- Contar o total de beneficiários únicos em Uberlândia em 2024
    SELECT
        COUNT(DISTINCT p.pessoa_nis) as total
    FROM
        pagamentos p
    JOIN
        municipios m ON p.municipio_siafi = m.codigo_siafi
    WHERE
        m.nome = 'UBERLANDIA' AND m.uf = 'MG'
        AND EXTRACT(YEAR FROM p.mes_referencia) = 2024
)
-- Apresentar os resultados finais e calcular a porcentagem
SELECT
    (SELECT total FROM TotalBeneficiarios) AS total_beneficiarios_uberlandia,
    (SELECT COUNT(*) FROM BeneficiariosContinuos) AS beneficiarios_dependentes_6_meses,
    -- Cálculo da porcentagem
    ROUND(
        ( (SELECT COUNT(*) FROM BeneficiariosContinuos)::DECIMAL / (SELECT total FROM TotalBeneficiarios)::DECIMAL ) * 100
    , 2) AS porcentagem_dependencia_continua;
/*================================================================================*/

/*5º CONSULTA: Auditoria de Dados: Pagamentos Individuais com Valor Superior a 200% da Média Municipal em 2024.*/

WITH MediaPorMunicipio AS ( 
    SELECT 
        municipio_siafi, 
        AVG(valor_parcela) AS valor_medio_municipal 
    FROM pagamentos 
    WHERE EXTRACT(YEAR FROM mes_referencia) = 2024 
    GROUP BY municipio_siafi 
) 
SELECT 
    pe.nome AS nome_pessoa, 
    m.nome AS municipio, 
    m.uf, 
    p.valor_parcela, 
    mpm.valor_medio_municipal 
FROM 
    pagamentos p 
JOIN 
    pessoa pe ON p.pessoa_nis = pe.nis 
JOIN 
    municipios m ON p.municipio_siafi = m.codigo_siafi 
JOIN 
    MediaPorMunicipio mpm ON p.municipio_siafi = mpm.municipio_siafi 
WHERE 
    p.valor_parcela > (mpm.valor_medio_municipal * 2) 
    AND EXTRACT(YEAR FROM p.mes_referencia) = 2024 
ORDER BY 
    p.valor_parcela DESC;
/*================================================================================*/

/*6º CONSULTA:  Municípios com Investimento Total Superior a R$ 50 Milhões.*/

SELECT
    m.nome AS nome_municipio,
    m.uf,
    SUM(p.valor_parcela) AS valor_total_pago,
    COUNT(DISTINCT p.pessoa_nis) AS quantidade_beneficiarios
FROM
    pagamentos AS p
JOIN
    municipios AS m ON p.municipio_siafi = m.codigo_siafi
GROUP BY
    m.codigo_siafi, m.nome, m.uf
HAVING
    SUM(p.valor_parcela) > 50000000
ORDER BY
    valor_total_pago DESC;
/*================================================================================*/

/*7º CONSULTA: Concentração de Recursos em Minas Gerais: Comparativo de Verbas entre 
a Capital (Belo Horizonte) e o Interior em 2024.*/

SELECT 
    CASE 
        WHEN m.nome = 'BELO HORIZONTE' THEN 'Capital (Belo Horizonte)' 
        ELSE 'Interior' 
    END AS localizacao, 
    SUM(p.valor_parcela) AS valor_total, 
    COUNT(DISTINCT p.pessoa_nis) AS total_beneficiarios 
FROM 
    pagamentos AS p 
JOIN 
    municipios AS m ON p.municipio_siafi = m.codigo_siafi 
WHERE 
    m.uf = 'MG' AND EXTRACT(YEAR FROM p.mes_referencia) = 2024 
GROUP BY 
    localizacao; 
/*================================================================================*/

/*8º CONSULTA: Variação no Número de Beneficiários por UF entre Janeiro e Junho de 2024.*/

SELECT
    m.uf,
    COUNT(DISTINCT CASE WHEN p.mes_referencia = '2024-01-01' THEN p.pessoa_nis END) AS beneficiarios_jan,
    COUNT(DISTINCT CASE WHEN p.mes_referencia = '2024-06-01' THEN p.pessoa_nis END) AS beneficiarios_jun,
    (COUNT(DISTINCT CASE WHEN p.mes_referencia = '2024-06-01' THEN p.pessoa_nis END) -
     COUNT(DISTINCT CASE WHEN p.mes_referencia = '2024-01-01' THEN p.pessoa_nis END)) AS variacao_absoluta
FROM
    pagamentos p
JOIN
    municipios m ON p.municipio_siafi = m.codigo_siafi
WHERE
    p.mes_referencia IN ('2024-01-01', '2024-06-01') -- Assumindo formato AAAA-MM-DD
GROUP BY
    m.uf
ORDER BY
    variacao_absoluta DESC;
/*================================================================================*/

/*9º CONSULTA: Mediana de Beneficiários Únicos por Município para Cada Estado.*/

WITH BeneficiariosPorMunicipio AS (
    SELECT
        m.uf,
        COUNT(DISTINCT p.pessoa_nis) AS total_beneficiarios
    FROM
        pagamentos p
    JOIN
        municipios m ON p.municipio_siafi = m.codigo_siafi
    WHERE
        m.uf != 'DF' -- Excluindo o Distrito Federal
    GROUP BY
        m.uf, m.nome
)
SELECT
    uf,
    -- PERCENTILE_CONT(0.5) calcula a mediana (percentil 50)
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_beneficiarios) AS mediana_beneficiarios_por_municipio
FROM
    BeneficiariosPorMunicipio
GROUP BY
    uf
ORDER BY
    mediana_beneficiarios_por_municipio DESC;
/*================================================================================*/

/*10º CONSULTA: Comparativo de Perfis de Vulnerabilidade: Top 10 Municípios por Valor 
Médio de Parcela (Nacional vs. Foco Demográfico).*/

WITH FocoDemografico AS (
    SELECT
        'Foco Demográfico' AS categoria,
        m.nome AS municipio,
        m.uf,
        AVG(p.valor_parcela) AS valor_medio_parcela,
        RANK() OVER (ORDER BY AVG(p.valor_parcela) DESC) AS ranking
    FROM pagamentos p
    JOIN municipios m ON p.municipio_siafi = m.codigo_siafi
    WHERE
        m.uf IN ('BA', 'PI', 'MA', 'PA', 'SE')
        AND TO_CHAR(p.mes_referencia, 'YYYY') = '2024'
    GROUP BY m.nome, m.uf
    LIMIT 10
),
Nacional AS (
    -- CTE para o Top 10 nacional
    SELECT
        'Nacional' AS categoria,
        m.nome AS municipio,
        m.uf,
        AVG(p.valor_parcela) AS valor_medio_parcela,
        RANK() OVER (ORDER BY AVG(p.valor_parcela) DESC) AS ranking
    FROM pagamentos p
    JOIN municipios m ON p.municipio_siafi = m.codigo_siafi
    WHERE
        TO_CHAR(p.mes_referencia, 'YYYY') = '2024'
    GROUP BY m.nome, m.uf
    LIMIT 10
)
-- Une os dois resultados em uma única tabela para comparação
SELECT categoria, ranking, municipio, uf, valor_medio_parcela
FROM FocoDemografico
UNION ALL
SELECT categoria, ranking, municipio, uf, valor_medio_parcela
FROM Nacional
ORDER BY ranking, categoria;
/*================================================================================*/

/*11º CONSULTA: Comparativo do Perfil de Pagamentos: Distribuição de Parcelas de 
Baixo e Alto Valor entre Grupos de Estados.*/

WITH PagamentosCategorizados AS (
    SELECT
        p.valor_parcela,
        CASE
            WHEN m.uf IN ('BA', 'PI', 'MA', 'PA', 'SE') THEN 'Foco Demográfico'
            ELSE 'Outros Estados'
        END AS grupo_demografico
    FROM
        pagamentos p
    JOIN
        municipios m ON p.municipio_siafi = m.codigo_siafi
    WHERE
        TO_CHAR(p.mes_referencia, 'YYYY') = '2024'
)
SELECT
    grupo_demografico,
    COUNT(*) AS total_de_pagamentos,
    COUNT(*) FILTER (WHERE valor_parcela <= 700) AS pagamentos_baixo_valor,
    COUNT(*) FILTER (WHERE valor_parcela > 700) AS pagamentos_alto_valor,
    -- Calculando o percentual para uma análise mais clara
    (COUNT(*) FILTER (WHERE valor_parcela > 700)::numeric / COUNT(*)) * 100 AS percentual_alto_valor
FROM
    PagamentosCategorizados
GROUP BY
    grupo_demografico;
/*================================================================================*/

/*12º CONSULTA: Perfil Estatístico do Valor das Parcelas por Estado (Mínimo, Máximo, 
Média e Desvio Padrão)*/
SELECT
    m.uf,
    MIN(p.valor_parcela) AS valor_minimo,
    MAX(p.valor_parcela) AS valor_maximo,
    AVG(p.valor_parcela) AS valor_medio,
    STDDEV(p.valor_parcela) AS desvio_padrao
FROM
    pagamentos p
JOIN
    municipios m ON p.municipio_siafi = m.codigo_siafi
WHERE
    TO_CHAR(p.mes_referencia, 'YYYY') = '2024'
GROUP BY
    m.uf
ORDER BY
    desvio_padrao DESC;
