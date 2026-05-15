                              /*Procedimento Armazenado e Gatilho*/
/*==============================================================================================*/

/*Procedimento Amrmazenado
Titulo: Raio-X de um Município
Ideia: Criar uma função que recebe o código SIAFI e o ano como 
parâmetros e retorna um resumo completo do impacto do Bolsa Família naquele 
município, incluindo valor total pago, número de beneficiários únicos, 
valor médio do benefício e os meses de início e fim de registros. */

CREATE TYPE tipo_raiox_municipio AS (
    nome_municipio VARCHAR(100), -- MUDANÇA AQUI: de TEXT para VARCHAR(100)
    uf CHAR(2),
    valor_total_pago NUMERIC,
    beneficiarios_unicos BIGINT,
    valor_medio_beneficio NUMERIC,
    primeiro_mes_registro DATE,
    ultimo_mes_registro DATE
);
-- Passo 2: Recriar a função (o corpo da função continua o mesmo)
CREATE OR REPLACE FUNCTION raiox_municipio_por_ano(p_codigo_siafi INTEGER, p_ano INTEGER)
RETURNS SETOF tipo_raiox_municipio AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.nome AS nome_municipio,
        m.uf,
        SUM(p.valor_parcela) AS valor_total_pago,
        COUNT(DISTINCT p.pessoa_nis) AS beneficiarios_unicos,
        AVG(p.valor_parcela) AS valor_medio_beneficio,
        MIN(p.mes_referencia) AS primeiro_mes_registro,
        MAX(p.mes_referencia) AS ultimo_mes_registro
    FROM
        pagamentos AS p
    JOIN
        municipios AS m ON p.municipio_siafi = m.codigo_siafi
    WHERE
        p.municipio_siafi = p_codigo_siafi
        AND EXTRACT(YEAR FROM p.mes_referencia) = p_ano -- <-- FILTRO DINÂMICO
    GROUP BY
        m.nome, m.uf;
END;
$$ LANGUAGE plpgsql;

/*Teste de Aplicação*/
-- Exemplo: Raio-X de Uberlândia em 2024 (supondo código 5403)
SELECT * FROM raiox_municipio_por_ano(5403, 2024);

/*Justificativa (Utilidade e Complexidade)*/
/*Este procedimento facilita o trabalho de gestores públicos, pois com um único comando é 
possível obter um diagnóstico detalhado de um município específico. A utilidade está em
centralizar cálculos complexos (SUM, COUNT, AVG, MIN, MAX) em uma função reutilizável. 
A complexidade vem da criação de um tipo customizado (CREATE TYPE) e do retorno estruturado 
(SETOF), que organiza os resultados em formato de relatório.*/
/*==============================================================================================*/

/*Gatilho
Título: Contagem Automática de beneficiários 
Ideia: Adicionar uma coluna qtd_beneficiarios na tabela municipios e criar um gatilho que, a 
cada novo pagamento inserido, verifique se aquele beneficiário está recebendo pela primeira vez 
no município. Se for o caso, o contador de beneficiários do município é incrementado automaticamente.*/

ALTER TABLE municipios ADD COLUMN qtd_beneficiarios INTEGER DEFAULT 0;

CREATE OR REPLACE FUNCTION atualizar_contagem_beneficiarios()
RETURNS TRIGGER AS $$
DECLARE
    v_municipio_siafi INTEGER;
BEGIN
    -- Descobre o município do primeiro pagamento da nova pessoa
    SELECT municipio_siafi INTO v_municipio_siafi 
    FROM pagamentos 
    WHERE pessoa_nis = NEW.nis 
    LIMIT 1;

    -- Se encontrou um município, atualiza a contagem
    IF v_municipio_siafi IS NOT NULL THEN
        UPDATE municipios
        SET qtd_beneficiarios = qtd_beneficiarios + 1
        WHERE codigo_siafi = v_municipio_siafi;
    END IF;

    RETURN NULL; -- O retorno é ignorado em triggers AFTER
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_atualiza_contagem_beneficiarios
AFTER INSERT ON pessoa
FOR EACH ROW
EXECUTE FUNCTION atualizar_contagem_beneficiarios();

/*Teste de Aplicação*/
-- 1. Verificar o estado inicial do contador de beneficiários do município
SELECT nome, qtd_beneficiarios 
FROM municipios
WHERE codigo_siafi = 5403;

-- 2. Inserir uma nova pessoa
INSERT INTO pessoa (nis, nome, cpf)  
VALUES (99999999999, 'BENEFICIARIO TESTE', '999.999.999-99');

-- 3. Inserir um pagamento para essa nova pessoa (aciona o gatilho)
INSERT INTO pagamentos (mes_competencia, mes_referencia, municipio_siafi, pessoa_nis, valor_parcela) 
VALUES ('2024-06-01', '2024-06-01', 5403, 99999999999, 700.00);

-- 4. Verificar se o contador foi incrementado
SELECT nome, qtd_beneficiarios 
FROM municipios 
WHERE codigo_siafi = 5403;

/*Justificativa (Utilidade e Complexidade
A utilidade do gatilho está em otimizar a análise de dados: em vez de executar consultas agregadas pesadas 
(como COUNT) toda vez que for necessário saber quantos beneficiários há em um município, o valor já fica 
atualizado em tempo real dentro da tabela municipios. Isso melhora a performance em consultas analíticas 
e relatórios. A complexidade está no fato de que o gatilho é do tipo AFTER INSERT, atua em uma tabela diferente 
daquela onde a operação ocorre (um INSERT em pessoa resulta em uma busca em pagamentos e um UPDATE em municipios), 
e precisa garantir consistência ao verificar se o pagamento inserido é realmente o primeiro daquele beneficiário.*/
