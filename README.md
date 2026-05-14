# 📊 Análise de Dados do Novo Bolsa Família — SQL & PostgreSQL

Projeto de estruturação, normalização e análise dos microdados públicos do programa **Novo Bolsa Família**, desenvolvido na disciplina de Sistemas de Banco de Dados (GBC043) da Universidade Federal de Uberlândia (UFU) em 2025.

---

## 📌 Sobre o Projeto

O objetivo é estruturar os dados públicos do programa em um banco de dados relacional e extrair informações relevantes que possam auxiliar na tomada de decisão e na compreensão do impacto socioeconômico do programa no Brasil.

O conjunto de dados utilizado consiste nos microdados públicos dos pagamentos do Novo Bolsa Família referentes ao **primeiro semestre de 2024**, disponibilizados pelo Portal da Transparência do Governo Federal.

---

## 🗃️ Modelagem do Banco de Dados

Os dados foram normalizados até a **Terceira Forma Normal (3FN)**, resultando em três tabelas principais:

| Tabela | Descrição |
|--------|-----------|
| `municipios` | Cadastro centralizado de municípios brasileiros (código SIAFI, nome, UF) |
| `pessoa` | Dados cadastrais únicos de cada beneficiário (NIS, nome, CPF) |
| `pagamentos` | Tabela de fatos com cada evento de pagamento (tabela principal) |

**Integridade referencial** garantida via chaves estrangeiras com políticas `ON DELETE RESTRICT` e `ON UPDATE CASCADE`.

---

## 🔍 Consultas Analíticas

O projeto inclui **12 consultas SQL complexas** para extração de insights socioeconômicos:

1. Histórico de pagamentos e verificação de retroativos por beneficiário
2. Concentração percentual e acumulada de recursos por estado (Princípio de Pareto)
3. Variação percentual mensal de beneficiários — Uberlândia vs. média de MG
4. Análise percentual de dependência contínua do programa em Uberlândia
5. Auditoria de pagamentos com valor superior a 200% da média municipal
6. Municípios com investimento total superior a R$ 50 milhões
7. Comparativo de recursos entre capital e interior de Minas Gerais
8. Variação no número de beneficiários por UF entre janeiro e junho de 2024
9. Mediana de beneficiários únicos por município para cada estado
10. Comparativo de perfis de vulnerabilidade — Top 10 municípios por valor médio de parcela
11. Distribuição de parcelas de baixo e alto valor entre grupos de estados
12. Perfil estatístico do valor das parcelas por estado (mínimo, máximo, média e desvio padrão)

---

## ⚙️ Stored Procedure & Trigger

### Stored Procedure — Raio-X de um Município
Função que recebe o código SIAFI e o ano como parâmetros e retorna um resumo completo do impacto do Bolsa Família naquele município (valor total, beneficiários únicos, valor médio, período de registros).

### Trigger — Contagem Automática de Beneficiários
Gatilho `AFTER INSERT` que atualiza automaticamente o contador de beneficiários por município a cada novo registro, otimizando a performance das consultas analíticas.

---

## 🛠️ Tecnologias Utilizadas

- **PostgreSQL** — Banco de dados relacional
- **SQL / PLpgSQL** — Consultas e stored procedures
- **Portal da Transparência** — Fonte dos dados públicos

---

## 📂 Como Reproduzir

1. Baixe os microdados em [dados.gov.br](https://dados.gov.br)
2. Execute o script de criação das tabelas (`CREATE TABLE`)
3. Importe os dados via tabela de staging
4. Execute as consultas analíticas

---

## 👩‍💻 Equipe

Projeto desenvolvido em equipe por estudantes de Ciência da Computação — UFU:

- Ana Alice Cordeiro de Souza
- Anna Karolyna Pereira Santos
- Ester Camilly Simplício de Freitas

**Orientação:** Profa. Maria Camila Nardini Barioni
