-- ========================================
-- Set active role with full admin privileges
-- ========================================
USE ROLE ACCOUNTADMIN; 

-- ========================================
-- Create database and schema for storing agent data
-- ========================================
CREATE DATABASE IF NOT EXISTS agent_gateway;
USE DATABASE agent_gateway;

CREATE SCHEMA IF NOT EXISTS ag_schema;

-- ========================================
-- Create a virtual warehouse to process queries and tasks
-- ========================================
CREATE OR REPLACE WAREHOUSE agent_wh;
USE WAREHOUSE agent_wh;

-- ========================================
-- Create custom Cortex role and link it to Snowflake Cortex privileges
-- ========================================
CREATE OR REPLACE ROLE cortex_user_role;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE cortex_user_role;

-- ========================================
-- Create users and assign roles
-- ========================================
CREATE OR REPLACE USER agent_user;
GRANT ROLE cortex_user_role TO USER agent_user;

-- Assign to your user (replace with real username if needed)
GRANT ROLE cortex_user_role TO USER mheino;

-- ========================================
-- Grant necessary warehouse permissions
-- ========================================
GRANT USAGE ON WAREHOUSE agent_wh TO ROLE cortex_user_role;
GRANT OPERATE ON WAREHOUSE agent_wh TO ROLE cortex_user_role;

-- ========================================
-- Grant full access to the database and schema
-- ========================================
GRANT ALL ON DATABASE agent_gateway TO ROLE cortex_user_role;
GRANT ALL ON SCHEMA ag_schema TO ROLE cortex_user_role;

-- ========================================
-- Set password for agent_user (not secure for prod environments)
-- ========================================
ALTER USER agent_user
SET PASSWORD = 'agent_user' MUST_CHANGE_PASSWORD = FALSE;

-- ========================================
-- Switch to cortex role to begin resource creation
-- ========================================
USE ROLE cortex_user_role;

-- ========================================
-- Create external stages for PDF documents and repair manuals
-- These are used as file storage sources
-- ========================================

-- Stage for storing VW documents
CREATE OR REPLACE STAGE agent_gateway.ag_schema.vw
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

-- Stage for storing VW repair manuals
CREATE OR REPLACE STAGE agent_gateway.ag_schema.repair_manual
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

-- Stage for storing VW semantic model
CREATE STAGE public DIRECTORY = (ENABLE = TRUE);
GRANT READ ON STAGE public TO ROLE PUBLIC;


-- ========================================
-- Create Python UDF to chunk PDF documents by page with overlap
-- This function adds overlap between adjacent pages for context
-- ========================================
CREATE OR REPLACE FUNCTION agent_gateway.ag_schema.pdf_text_chunker(file_url STRING)
    RETURNS TABLE (chunk VARCHAR, page_number INT)
    LANGUAGE PYTHON
    RUNTIME_VERSION = '3.9'
    HANDLER = 'pdf_text_chunker'
    PACKAGES = ('snowflake-snowpark-python', 'PyPDF2', 'langchain')
AS
$$
from snowflake.snowpark.types import StringType, StructField, StructType
from langchain.text_splitter import RecursiveCharacterTextSplitter
from snowflake.snowpark.files import SnowflakeFile
import PyPDF2
import io
import logging
import pandas as pd

class pdf_text_chunker:

    def read_pdf(self, file_url: str):
        logger = logging.getLogger("udf_logger")
        logger.info(f"Opening file {file_url}")

        with SnowflakeFile.open(file_url, 'rb') as f:
            buffer = io.BytesIO(f.readall())

        reader = PyPDF2.PdfReader(buffer)
        page_texts = []
        for i, page in enumerate(reader.pages):
            try:
                text = page.extract_text().replace('\n', ' ').replace('\0', ' ')
                page_texts.append((text, i + 1))  # 1-based page indexing
            except Exception as e:
                logger.warning(f"Unable to extract from file {file_url}, page {i + 1}: {e}")
                page_texts.append(("Unable to Extract", i + 1))

        return page_texts

    def process(self, file_url: str):
        page_texts = self.read_pdf(file_url)
        num_pages = len(page_texts)

        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=2000,
            chunk_overlap=300,
            length_function=len
        )

        chunks_with_page_numbers = []
        for i, (text, page_num) in enumerate(page_texts):
            prev_overlap = page_texts[i - 1][0][-300:] if i > 0 else ''
            next_overlap = page_texts[i + 1][0][:300] if i < num_pages - 1 else ''
            combined_text = f"{prev_overlap} {text} {next_overlap}".strip()
            chunks = text_splitter.split_text(combined_text)
            for chunk in chunks:
                chunks_with_page_numbers.append((chunk, page_num))

        df = pd.DataFrame(chunks_with_page_numbers, columns=['chunk', 'page_number'])
        yield from df.itertuples(index=False, name=None)
$$;

-- ========================================
-- Test the PDF chunker using a sample PDF from VW stage
-- ========================================
SELECT *
FROM TABLE(agent_gateway.ag_schema.pdf_text_chunker(
    BUILD_SCOPED_FILE_URL(@agent_gateway.ag_schema.vw, 'transporter-with-wbx-vag-self-study-programme.pdf')
));

-- ========================================
-- Chunk all files in the VW document stage and store in a table
-- ========================================
CREATE OR REPLACE TABLE agent_gateway.ag_schema.man_chunks_vw_documents AS
SELECT
    relative_path,
    build_scoped_file_url(@agent_gateway.ag_schema.vw, relative_path) AS file_url,
    CONCAT(relative_path, ': ', func.chunk) AS chunk,
    func.page_number,
    'English' AS language
FROM
    directory(@agent_gateway.ag_schema.vw),
    TABLE(agent_gateway.ag_schema.pdf_text_chunker(
        build_scoped_file_url(@agent_gateway.ag_schema.vw, relative_path)
    )) AS func;

-- ========================================
-- Create Cortex Search Service for VW documents
-- Enables semantic document search with hourly refresh
-- ========================================
CREATE OR REPLACE CORTEX SEARCH SERVICE agent_gateway.ag_schema.vw_documents
  ON chunk
  ATTRIBUTES relative_path
  WAREHOUSE = agent_wh
  TARGET_LAG = '1 hour'
  EMBEDDING_MODEL = 'snowflake-arctic-embed-m-v1.5'
AS (
  SELECT
      relative_path,
      file_url,
      chunk,
      page_number
  FROM agent_gateway.ag_schema.man_chunks_vw_documents
);

-- ========================================
-- Sample query to test VW document search service
-- ========================================
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
      'agent_gateway.ag_schema.vw_documents',
      '{
        "query": "what diesel options do I have",
        "columns":[
            "relative_path",
            "file_url",
            "chunk",
            "page_number"
        ], 
        "limit":1
      }'
  )
)['results'] AS results;

-- ========================================
-- Chunk and insert files from repair manuals into a new table
-- ========================================
CREATE OR REPLACE TABLE agent_gateway.ag_schema.man_chunks_repair_manuals AS
SELECT
    relative_path,
    build_scoped_file_url(@agent_gateway.ag_schema.repair_manual, relative_path) AS file_url,
    CONCAT(relative_path, ': ', func.chunk) AS chunk,
    func.page_number,
    'English' AS language
FROM
    directory(@agent_gateway.ag_schema.repair_manual),
    TABLE(agent_gateway.ag_schema.pdf_text_chunker(
        build_scoped_file_url(@agent_gateway.ag_schema.repair_manual, relative_path)
    )) AS func;

-- ========================================
-- Create Cortex Search Service for repair manuals
-- ========================================
CREATE OR REPLACE CORTEX SEARCH SERVICE agent_gateway.ag_schema.repair_manuals
  ON chunk
  ATTRIBUTES relative_path
  WAREHOUSE = agent_wh
  TARGET_LAG = '1 hour'
  EMBEDDING_MODEL = 'snowflake-arctic-embed-m-v1.5'
AS (
  SELECT
      relative_path,
      file_url,
      chunk,
      page_number
  FROM agent_gateway.ag_schema.man_chunks_repair_manuals
);

-- ========================================
-- Sample query to test repair manual search service
-- ========================================
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
      'agent_gateway.ag_schema.repair_manuals',
      '{
        "query": "how to change clutch",
        "columns":[
            "relative_path",
            "file_url",
            "chunk",
            "page_number"
        ], 
        "limit":1
      }'
  )
)['results'] AS results;


--- Cortex Analyst Setup

-- ====================================================================
-- Table Creation: Type25ChassisCodes
-- Purpose: Stores chassis code information for Type 25 vehicles,
--          including the production month, year, and chassis number.
-- ====================================================================
CREATE OR REPLACE TABLE AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (
    Month VARCHAR(10),        -- Production month (e.g., 'May', 'Aug').
    Year INT,                 -- Production year (e.g., 1980, 1981).
    ChassisNumber VARCHAR(15) -- Unique chassis identifier.
);

-- Insert records into the Type25ChassisCodes table.
-- Each entry corresponds to a specific production period and chassis number.
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('May', 1980, '24-A-00000001');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1980, '24-A-0013069');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1980, '25-A-0000410');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1980, '24-A-0150805');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1981, '24-B-0000001');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1981, '24-B-095074');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jun', 1981, '24-B-175000');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1982, '24-C-0000001');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1982, '24-C-089151');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1982, '24-C-175000');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1983, '24-D-0000001');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1983, '24-D-062766');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1983, '24-D-175000');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1984, '24-E-0000001');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1984, '24-E-081562');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1984, '24-E-175000');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1985, '24-F-0000001');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1985, '24-F-073793');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1985, '24-F-175000');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1986, '24-G-0000001');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1986, '24-G-068279');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1986, '24-G-175000');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1987, '24-H-0000001');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1987, '24-H-072878');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1987, '24-H-175000');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1988, '24-J-0000001');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1988, '24-J-060498');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1988, '24-J-120000');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1989, '24-K-0000001');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1989, '24-K-077876');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1989, '24-K-175000');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1990, '24-L-0000001');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1990, '24-L-056781');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1990, '24-L-175000');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1991, '24-M-0000001');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1991, '24-M-010527');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1991, '24-M-020000');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1992, '24-N-002182');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1992, '24-N-002183');
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1992, '24-N-015000');

-- ====================================================================
-- Table Creation: CountryOfManufacture
-- Purpose: Maps country codes to their respective country names.
-- ====================================================================
CREATE OR REPLACE TABLE AGENT_GATEWAY.AG_SCHEMA.CountryOfManufacture (
    Code CHAR(1) PRIMARY KEY, -- Single-character country code (e.g., 'W').
    Country VARCHAR(50)       -- Full country name (e.g., 'Germany').
);

-- Insert the country code for Germany.
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.CountryOfManufacture (Code, Country) VALUES ('W', 'Germany');

-- ====================================================================
-- Table Creation: Manufacturer
-- Purpose: Maps manufacturer codes to their respective manufacturer names.
-- ====================================================================
CREATE OR REPLACE TABLE AGENT_GATEWAY.AG_SCHEMA.Manufacturer (
    Code CHAR(1) PRIMARY KEY, -- Single-character manufacturer code (e.g., 'V').
    Name VARCHAR(50)          -- Manufacturer name (e.g., 'Volkswagen').
);

-- Insert the manufacturer code for Volkswagen.
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.Manufacturer (Code, Name) VALUES ('V', 'Volkswagen');

-- ====================================================================
-- Table Creation: VehicleBodyType
-- Purpose: Defines various vehicle body types associated with specific codes.
-- ====================================================================
CREATE OR REPLACE TABLE AGENT_GATEWAY.AG_SCHEMA.VehicleBodyType (
    Code CHAR(1) PRIMARY KEY, -- Single-character body type code (e.g., '1').
    Description VARCHAR(50)   -- Description of the body type (e.g., 'Pickup Truck').
);

-- Insert records for different vehicle body types.
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.VehicleBodyType (Code, Description) VALUES
('1', 'Pickup Truck'),
('2', 'MPV (Multi-Purpose Vehicle)');

-- ====================================================================
-- Table Creation: VehicleSeries
-- Purpose: Defines various vehicle series associated with specific codes.
-- ====================================================================
CREATE OR REPLACE TABLE AGENT_GATEWAY.AG_SCHEMA.VehicleSeries (
    Code CHAR(1) PRIMARY KEY, -- Single-character series code (e.g., 'U').
    Description VARCHAR(50)   -- Description of the vehicle series (e.g., '1980-91 Single-Cab Pickup (Pritschewagen)').
);

-- Insert records for different vehicle series.
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.VehicleSeries (Code, Description) VALUES
('U', '1980-91 Single-Cab Pickup (Pritschewagen)'),
('V', '1980-91 Double-Cab Pickup (Doppelkabine)'),
('W', '1980-91 Panel Van (no side windows)'),
('X', '1980-91 Kombi'),
('Y', '1980-91 Bus (Vanagon)'),
('Z', '1980-91 Camper');

-- ====================================================================
-- Table Creation: YearOfManufacture
-- Purpose: Maps year codes to their respective manufacturing years.
-- ====================================================================
CREATE OR REPLACE TABLE AGENT_GATEWAY.AG_SCHEMA.YearOfManufacture (
    Code CHAR(1) PRIMARY KEY, -- Single-character year code (e.g., 'B').
    Year INT                  -- Corresponding manufacturing year (e.g., 1981).
);

-- Insert records mapping year codes to actual years.
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.YearOfManufacture (Code, Year) VALUES
('B', 1981),
('C', 1982),
('D', 1983),
('E', 1984),
('F', 1985),
('G', 1986),
('H', 1987),
('J', 1988),
('K', 1989),
('L', 1990),
('M', 1991);

-- ====================================================================
-- Table Creation: AssemblyPlant
-- Purpose: Maps assembly plant codes to their respective locations.
-- ====================================================================
CREATE OR REPLACE TABLE AGENT_GATEWAY.AG_SCHEMA.AssemblyPlant (
    Code CHAR(1) PRIMARY KEY, -- Single-character assembly plant code (e.g., 'A').
    Location VARCHAR(50)      -- Location of the assembly plant (e.g., 'Ingolstadt').
);

-- Insert records for different assembly plant locations.
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.AssemblyPlant (Code, Location) VALUES
('A', 'Ingolstadt'),
('B', 'Brussels'),
('E', 'Emden'),
('G', 'Graz (Austria for Syncro models)'),
('H', 'Hannover'),
('K', 'Osnabrück'),
('M', 'Mexico'),
('N', 'Neckarsulm'),
('P', 'Brazil'),
('S', 'Stuttgart'),
('W', 'Wolfsburg');

-- ====================================================================
-- Table Creation: VW_Type25_VIN_Master
-- Purpose: Central repository for Vehicle Identification Numbers (VINs)
--          of Type 25 vehicles, linking to various attribute tables.
-- ====================================================================
CREATE OR REPLACE TABLE AGENT_GATEWAY.AG_SCHEMA.VW_Type25_VIN_Master (
    VIN VARCHAR(17) PRIMARY KEY,          -- 17-character Vehicle Identification Number.
    CountryOfManufacture CHAR(1),         -- Foreign key referencing CountryOfManufacture(Code).
    Manufacturer CHAR(1),                 -- Foreign key referencing Manufacturer(Code).
    VehicleBodyType CHAR(1),              -- Foreign key referencing VehicleBodyType(Code).
    VehicleSeries CHAR(1),                -- Foreign key referencing VehicleSeries(Code).
    YearOfManufacture CHAR(1),            -- Foreign key referencing YearOfManufacture(Code).
    AssemblyPlant CHAR(1),                -- Foreign key referencing AssemblyPlant(Code).
    ChassisNumber VARCHAR(6),             -- Unique chassis number.
    FOREIGN KEY (CountryOfManufacture) REFERENCES AGENT_GATEWAY.AG_SCHEMA.CountryOfManufacture(Code),
    FOREIGN KEY (Manufacturer) REFERENCES AGENT_GATEWAY.AG_SCHEMA.Manufacturer(Code),
    FOREIGN KEY (VehicleBodyType) REFERENCES AGENT_GATEWAY.AG_SCHEMA.VehicleBodyType(Code),
    FOREIGN KEY (VehicleSeries) REFERENCES AGENT_GATEWAY.AG_SCHEMA.VehicleSeries(Code),
    FOREIGN KEY (YearOfManufacture) REFERENCES AGENT_GATEWAY.AG_SCHEMA.YearOfManufacture(Code),
    FOREIGN KEY (AssemblyPlant) REFERENCES AGENT_GATEWAY.AG_SCHEMA.AssemblyPlant(Code)
);

-- Insert a sample VIN record into the VW_Type25_VIN_Master table.
-- This entry corresponds to a vehicle manufactured in Germany by Volkswagen,
-- with specific attributes decoded from the VIN.
INSERT INTO AGENT_GATEWAY.AG_SCHEMA.VW_Type25_VIN_Master (
    VIN,
    CountryOfManufacture,
    Manufacturer,
    VehicleBodyType,
    VehicleSeries,
    YearOfManufacture,
    AssemblyPlant,
    ChassisNumber
) VALUES (
    'WV2ZZZ25ZEH0000',
    'W',
    'V',
    '2',
    '5',
    'E',
    'H',
    '0000'
);
