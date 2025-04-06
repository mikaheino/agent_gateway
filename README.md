# Volkswagen T2.5/T3 AI Assistant via Snowflake Agent Gateway

This project shows how to build an AI agent using **Snowflake's Agent Gateway** to answer diagnostic and spare part questions for Volkswagen T2.5/T3 vehicles. The solution uses Snowflake Cortex tools (Search & Analyst) and a Python-based web scraping tool to retrieve and synthesize information.

---

## ✨ Use Case

> "XXX is broken. My VW VIN is XXXXXX. Which part do I need, and what are the expected costs?"

This agent combines structured and unstructured data:
- Repair manuals & owner documentation (1980–1990)
- VIN/chassis codes and vehicle metadata
- Live part prices from eBay, Autoteile-Mark, Paruzzi, and Autodoc

---

## 🧰 Project Architecture

### Agent Gateway Components:
- **Agent Orchestrator (Gateway)**: Main controller, handles input/output
- **Task Planner**: Breaks questions into tasks using LLM
- **Executor**: Executes tasks, fuses results into final answer

### Tools Used:
- **Cortex Search** – for document (PDF) search using RAG
- **Cortex Analyst** – for VIN decoding (Text2SQL)
- **Python Tool** – for live part price scraping
- **SQL Tool** – for querying Snowflake directly

---

## ⚙ Setup Instructions

### 1. Snowflake Setup
- Create database/schema/warehouse:
```sql
CREATE DATABASE IF NOT EXISTS agent_gateway;
CREATE SCHEMA IF NOT EXISTS ag_schema;
CREATE OR REPLACE WAREHOUSE agent_wh;
```
- Create user and role with Cortex permissions
- Create internal stages for PDF documents

### 2. Upload & Parse Documents
- Use `CORTEX.PARSE_DOCUMENT()` with OCR mode
- For better results, use custom `pdf_text_chunker()` Python UDF via Snowpark (uses PyPDF2 + LangChain)

### 3. Prepare Search Data
- Store chunks into Snowflake table `man_chunks_vw_documents`
- Create `CORTEX SEARCH SERVICE` on the chunk column

### 4. VIN Metadata Setup
- Create structured tables: `VW_Type25_VIN_Master`, `ChassisCodes`, `Country`, `Manufacturer`, `AssemblyPlant`, etc.
- Create `CORTEX ANALYST` semantic model (`volkswagen.yaml`)

---

## 🚀 Agent Gateway Installation

### Install Python Dependencies:
```bash
pip install orchestration-framework snowflake-snowpark-python PyPDF2 langchain beautifulsoup4 requests python-dotenv
```

### Initialize Tools:
```python
from agent_gateway import Agent
from agent_gateway.tools import CortexSearchTool, CortexAnalystTool, PythonTool
```

- Define configs for `CortexSearchTool`, `CortexAnalystTool`
- Add custom Python function `get_average_part_price(oem_number)` for live scraping

### Run Agent:
```bash
python3 agent.py
```

Example CLI session:
```
You: what parts do I need for clutch fix?
Agent: For a clutch fix... [fused answer from CortexSearch]
```

---

## 🔍 Web Scraper Tool
A custom PythonTool was created for scraping spare part prices using OEM numbers. Vendors supported:
- eBay (prices converted from GBP to EUR)
- Autoteile-markt.de
- Paruzzi.com
- Autodoc.fi

Returns:
- Average price
- Prices grouped by vendor

---

## 🌟 Conclusion

This is a functional prototype for agentic orchestration combining:
- Document parsing & semantic search (Cortex Search)
- Structured VIN decoding (Cortex Analyst)
- Live price lookups (Python Tool)

The agent can be further wrapped in Streamlit UI or deployed using Snowflake Container Services.

> The project shows what's possible when Snowflake tools are extended with Python to build multi-modal AI assistants.

---

## 📅 TODOs / Future Improvements
- Improve document chunking with page/image reference
- Add multimodal support (PDF diagrams)
- Extend search to support fuzzy VIN matching
- UI via Streamlit or FastAPI

---

## 🔗 References
- https://github.com/Snowflake-Labs/orchestration-framework
- https://docs.snowflake.com/en/user-guide/snowflake-cortex
