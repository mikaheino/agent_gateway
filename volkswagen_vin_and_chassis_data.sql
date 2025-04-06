-- Set the role to ACCOUNTADMIN to ensure appropriate access rights.
USE ROLE ACCOUNTADMIN;

-- Select the AGENT_GATEWAY database.
USE DATABASE AGENT_GATEWAY;

-- Switch to the ag_schema schema within the selected database.
USE SCHEMA ag_schema;

-- ====================================================================
-- Table Creation: Type25ChassisCodes
-- Purpose: Stores chassis code information for Type 25 vehicles,
--          including the production month, year, and chassis number.
-- ====================================================================
CREATE TABLE Type25ChassisCodes (
    Month VARCHAR(10),        -- Production month (e.g., 'May', 'Aug').
    Year INT,                 -- Production year (e.g., 1980, 1981).
    ChassisNumber VARCHAR(15) -- Unique chassis identifier.
);

-- Insert records into the Type25ChassisCodes table.
-- Each entry corresponds to a specific production period and chassis number.
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('May', 1980, '24-A-00000001');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1980, '24-A-0013069');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1980, '25-A-0000410');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1980, '24-A-0150805');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1981, '24-B-0000001');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1981, '24-B-095074');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jun', 1981, '24-B-175000');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1982, '24-C-0000001');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1982, '24-C-089151');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1982, '24-C-175000');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1983, '24-D-0000001');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1983, '24-D-062766');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1983, '24-D-175000');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1984, '24-E-0000001');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1984, '24-E-081562');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1984, '24-E-175000');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1985, '24-F-0000001');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1985, '24-F-073793');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1985, '24-F-175000');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1986, '24-G-0000001');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1986, '24-G-068279');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1986, '24-G-175000');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1987, '24-H-0000001');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1987, '24-H-072878');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1987, '24-H-175000');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1988, '24-J-0000001');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1988, '24-J-060498');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1988, '24-J-120000');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1989, '24-K-0000001');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1989, '24-K-077876');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1989, '24-K-175000');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1990, '24-L-0000001');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1990, '24-L-056781');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1990, '24-L-175000');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1991, '24-M-0000001');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1991, '24-M-010527');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1991, '24-M-020000');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Aug', 1992, '24-N-002182');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jan', 1992, '24-N-002183');
INSERT INTO Type25ChassisCodes (Month, Year, ChassisNumber) VALUES ('Jul', 1992, '24-N-015000');

-- ====================================================================
-- Table Creation: CountryOfManufacture
-- Purpose: Maps country codes to their respective country names.
-- ====================================================================
CREATE TABLE CountryOfManufacture (
    Code CHAR(1) PRIMARY KEY, -- Single-character country code (e.g., 'W').
    Country VARCHAR(50)       -- Full country name (e.g., 'Germany').
);

-- Insert the country code for Germany.
INSERT INTO CountryOfManufacture (Code, Country) VALUES ('W', 'Germany');

-- ====================================================================
-- Table Creation: Manufacturer
-- Purpose: Maps manufacturer codes to their respective manufacturer names.
-- ====================================================================
CREATE TABLE Manufacturer (
    Code CHAR(1) PRIMARY KEY, -- Single-character manufacturer code (e.g., 'V').
    Name VARCHAR(50)          -- Manufacturer name (e.g., 'Volkswagen').
);

-- Insert the manufacturer code for Volkswagen.
INSERT INTO Manufacturer (Code, Name) VALUES ('V', 'Volkswagen');

-- ====================================================================
-- Table Creation: VehicleBodyType
-- Purpose: Defines various vehicle body types associated with specific codes.
-- ====================================================================
CREATE TABLE VehicleBodyType (
    Code CHAR(1) PRIMARY KEY, -- Single-character body type code (e.g., '1').
    Description VARCHAR(50)   -- Description of the body type (e.g., 'Pickup Truck').
);

-- Insert records for different vehicle body types.
INSERT INTO VehicleBodyType (Code, Description) VALUES
('1', 'Pickup Truck'),
('2', 'MPV (Multi-Purpose Vehicle)');

-- ====================================================================
-- Table Creation: VehicleSeries
-- Purpose: Defines various vehicle series associated with specific codes.
-- ====================================================================
CREATE TABLE VehicleSeries (
    Code CHAR(1) PRIMARY KEY, -- Single-character series code (e.g., 'U').
    Description VARCHAR(50)   -- Description of the vehicle series (e.g., '1980-91 Single-Cab Pickup (Pritschewagen)').
);

-- Insert records for different vehicle series.
INSERT INTO VehicleSeries (Code, Description) VALUES
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
CREATE TABLE YearOfManufacture (
    Code CHAR(1) PRIMARY KEY, -- Single-character year code (e.g., 'B').
    Year INT                  -- Corresponding manufacturing year (e.g., 1981).
);

-- Insert records mapping year codes to actual years.
INSERT INTO YearOfManufacture (Code, Year) VALUES
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
CREATE TABLE AssemblyPlant (
    Code CHAR(1) PRIMARY KEY, -- Single-character assembly plant code (e.g., 'A').
    Location VARCHAR(50)      -- Location of the assembly plant (e.g., 'Ingolstadt').
);

-- Insert records for different assembly plant locations.
INSERT INTO AssemblyPlant (Code, Location) VALUES
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
CREATE OR REPLACE TABLE VW_Type25_VIN_Master (
    VIN VARCHAR(17) PRIMARY KEY,          -- 17-character Vehicle Identification Number.
    CountryOfManufacture CHAR(1),         -- Foreign key referencing CountryOfManufacture(Code).
    Manufacturer CHAR(1),                 -- Foreign key referencing Manufacturer(Code).
    VehicleBodyType CHAR(1),              -- Foreign key referencing VehicleBodyType(Code).
    VehicleSeries CHAR(1),                -- Foreign key referencing VehicleSeries(Code).
    YearOfManufacture CHAR(1),            -- Foreign key referencing YearOfManufacture(Code).
    AssemblyPlant CHAR(1),                -- Foreign key referencing AssemblyPlant(Code).
    ChassisNumber VARCHAR(6),             -- Unique chassis number.
    FOREIGN KEY (CountryOfManufacture) REFERENCES CountryOfManufacture(Code),
    FOREIGN KEY (Manufacturer) REFERENCES Manufacturer(Code),
    FOREIGN KEY (VehicleBodyType) REFERENCES VehicleBodyType(Code),
    FOREIGN KEY (VehicleSeries) REFERENCES VehicleSeries(Code),
    FOREIGN KEY (YearOfManufacture) REFERENCES YearOfManufacture(Code),
    FOREIGN KEY (AssemblyPlant) REFERENCES AssemblyPlant(Code)
);

-- Insert a sample VIN record into the VW_Type25_VIN_Master table.
-- This entry corresponds to a vehicle manufactured in Germany by Volkswagen,
-- with specific attributes decoded from the VIN.
INSERT INTO VW_Type25_VIN_Master (
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
 
