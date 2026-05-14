-- =============================================
-- SCRIPT DE RESET TOTAL DO PROJETO SBD
-- =============================================

-- Cria a base de dados do projeto, se ela não existir
-- Se este comando falhar porque a base já existe, não tem problema, continue.
CREATE DATABASE projetosbd;

-- A PARTIR DAQUI, EXECUTE CONECTADO À BASE 'projetosbd'

-- Apaga as tabelas antigas na ordem correta, se existirem
DROP TABLE IF EXISTS pagamentos;
DROP TABLE IF EXISTS pessoa;
DROP TABLE IF EXISTS municipios;
DROP TABLE IF EXISTS staging_pagamentos;

-- Cria as tabelas finais
CREATE TABLE municipios ( codigo_siafi INTEGER PRIMARY KEY, nome VARCHAR(100) NOT NULL, uf CHAR(2) NOT NULL );
CREATE TABLE pessoa ( nis BIGINT PRIMARY KEY, nome VARCHAR(150) NOT NULL, cpf VARCHAR(14) );
CREATE TABLE pagamentos ( id_pagamento SERIAL PRIMARY KEY, mes_competencia DATE NOT NULL, mes_referencia DATE NOT NULL, municipio_siafi INTEGER NOT NULL, pessoa_nis BIGINT NOT NULL, valor_parcela DECIMAL(10, 2) NOT NULL, CONSTRAINT fk_pessoa FOREIGN KEY(pessoa_nis) REFERENCES pessoa(nis) ON DELETE RESTRICT ON UPDATE CASCADE, CONSTRAINT fk_municipio FOREIGN KEY(municipio_siafi) REFERENCES municipios(codigo_siafi) ON DELETE RESTRICT ON UPDATE CASCADE );

-- Cria a tabela de passagem com TODAS as colunas como TEXTO
CREATE TABLE staging_pagamentos ( mes_competencia TEXT, mes_referencia TEXT, uf TEXT, codigo_municipio_siafi TEXT, nome_municipio TEXT, cpf_favorecido TEXT, nis_favorecido TEXT, nome_favorecido TEXT, valor_parcela TEXT );
