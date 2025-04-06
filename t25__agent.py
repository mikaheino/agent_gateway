from agent_gateway import Agent
from agent_gateway.tools import CortexSearchTool, CortexAnalystTool, PythonTool
from snowflake.snowpark import Session
import os
import re
import statistics
import requests
from dotenv import load_dotenv
from bs4 import BeautifulSoup

load_dotenv()

# Set environment variables
os.environ["SNOWFLAKE_ACCOUNT"] = "Your Snowflake Account"
os.environ["SNOWFLAKE_USERNAME"] = "agent_user"
os.environ["SNOWFLAKE_PASSWORD"] = "agent_user"
os.environ["SNOWFLAKE_DATABASE"] = "agent_gateway"
os.environ["SNOWFLAKE_SCHEMA"] = "ag_schema"
os.environ["SNOWFLAKE_ROLE"] = "cortex_user_role"
os.environ["SNOWFLAKE_WAREHOUSE"] = "agent_wh"

# Retrieve environment variables and define connection parameters
connection_parameters = {
    "account": os.getenv("SNOWFLAKE_ACCOUNT"),
    "user": os.getenv("SNOWFLAKE_USERNAME"),
    "password": os.getenv("SNOWFLAKE_PASSWORD"),
    "role": os.getenv("SNOWFLAKE_ROLE"),
    "warehouse": os.getenv("SNOWFLAKE_WAREHOUSE"),
    "database": os.getenv("SNOWFLAKE_DATABASE"),
    "schema": os.getenv("SNOWFLAKE_SCHEMA"),
}

# Create Snowpark session
snowpark = Session.builder.configs(connection_parameters).create()

# Define configurations for existing tools
search_config = {
    "service_name": "VW_DOCUMENTS",
    "service_topic": "Volkswagen T2.5/T3 repair documents",
    "data_description": "Volkswagen T2.5/T3 repair documents with parts needed to replace",
    "retrieval_columns": ["CHUNK", "RELATIVE_PATH", "PAGE_NUMBER"],
    "snowflake_connection": snowpark,
    "k": 10,
}

analyst_config = {
    "semantic_model": "volkswagen.yaml",
    "stage": "PUBLIC",
    "service_topic": "Deconstruct or identify Volkswagen using VIN",
    "data_description": "Information on how to deconstruct a VIN to identify Volkswagen model",
    "snowflake_connection": snowpark
}


def get_average_part_price(oem_number):
    GBP_TO_EUR = 1.17
    HEADERS = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    }

    def normalize_oem(oem):
        return re.sub(r"[^a-zA-Z0-9]", "", oem).lower()

    def extract_price(text):
        match = re.search(r"([0-9]+[\.,]?[0-9]*)", text.replace(',', '.'))
        return float(match.group(1)) if match else None

    def scrape_ebay_parts(oem):
        url = f"https://www.ebay.com/sch/i.html?_nkw={oem}+vw&_sacat=60200"
        response = requests.get(url, headers=HEADERS)
        soup = BeautifulSoup(response.text, 'html.parser')
        items = soup.select(".s-item")
        return [("ebay", extract_price(item.select_one(".s-item__price").text))
                for item in items
                if item.select_one(".s-item__title")
                and item.select_one(".s-item__price")
                and oem.lower() in item.select_one(".s-item__title").text.lower()]

    def scrape_autoteilemarkt_parts(oem):
        url = f"https://www.autoteile-markt.de/ersatzteile-suche?search_term={oem}"
        response = requests.get(url, headers=HEADERS)
        soup = BeautifulSoup(response.text, 'html.parser')
        items = soup.select(".article-list__item")
        return [("autoteile", extract_price(item.select_one(".article-list__price").text))
                for item in items
                if item.select_one(".article-list__name")
                and item.select_one(".article-list__price")
                and oem.lower() in item.select_one(".article-list__name").text.lower()]

    def scrape_paruzzi_parts(oem):
        url = f"https://www.paruzzi.com/uk/volkswagen/?zoektrefwoord={oem}"
        response = requests.get(url, headers=HEADERS)
        soup = BeautifulSoup(response.text, 'html.parser')
        items = soup.select(".product")
        return [("paruzzi", extract_price(item.select_one(".product-price").text))
                for item in items
                if item.select_one(".product-title")
                and item.select_one(".product-price")
                and oem.lower() in item.select_one(".product-title").text.lower()]

    def scrape_autodoc_parts(oem):
        url = f"https://www.autodoc.fi/autonosat/oem/{oem.lower()}"
        response = requests.get(url, headers=HEADERS)
        soup = BeautifulSoup(response.text, 'html.parser')
        prices = []
        for price_elem in soup.select('.product-list-item__price .price'):
            match = re.search(r"([0-9]+,[0-9]{2})", price_elem.get_text(strip=True))
            if match:
                try:
                    price_float = float(match.group(1).replace(',', '.'))
                    prices.append(("autodoc", price_float))
                except ValueError:
                    continue
        return prices

    oem_clean = normalize_oem(oem_number)

    all_prices = (
        scrape_ebay_parts(oem_clean)
        + scrape_autoteilemarkt_parts(oem_clean)
        + scrape_paruzzi_parts(oem_clean)
        + scrape_autodoc_parts(oem_clean)
    )

    prices_by_vendor = {}
    all_eur_prices = []

    for vendor, price in all_prices:
        if price is None:
            continue
        eur_price = round(price * GBP_TO_EUR, 2) if vendor == "ebay" else round(price, 2)
        prices_by_vendor.setdefault(vendor, []).append(eur_price)
        all_eur_prices.append(eur_price)

    if not all_eur_prices:
        return {
            "oem": oem_number,
            "average_price": None,
            "currency": "EUR",
            "prices_by_vendor": {},
            "note": "No valid prices found"
        }

    return {
        "oem": oem_number,
        "prices_by_vendor": prices_by_vendor,
        "average_price": round(statistics.mean(all_eur_prices), 2),
        "currency": "EUR"
    }



python_scraper_config = {
    "tool_description": "takes OEM part as input and returns the price of part if found",
    "output_description": "price of a Volkswagen OEM part",
    "python_func": get_average_part_price
    }

web_crawler = PythonTool(**python_scraper_config)



# Initialize existing tools
vw_man = CortexSearchTool(**search_config)
vw_vin = CortexAnalystTool(**analyst_config)
vw_prt = PythonTool(**python_scraper_config)

# Update the agent's tools
snowflake_tools = [vw_man, vw_vin, vw_prt]
agent = Agent(snowflake_connection=snowpark, tools=snowflake_tools, max_retries=3)

def interactive_shell():
    print("Interactive Agent Shell. Type 'exit' or 'quit' to end the session.")
    while True:
        try:
            user_input = input("You: ")
            if user_input.lower() in ['exit', 'quit']:
                print("Exiting interactive session.")
                break

            response = agent(user_input)

            # Check if the response is a dictionary
            if isinstance(response, dict):
                output = response.get("output")
                sources = response.get("sources")

                if output:
                    print("\n🛠️ Suggested Repair Parts:\n")
                    print(output)

                if sources:
                    print("\n📚 Sources:")
                    for source in sources:
                        tool_name = source.get("tool_name", "Unknown Tool")
                        print(f"- Tool: {tool_name}")
                        metadata = source.get("metadata", [])
                        for meta in metadata:
                            if isinstance(meta, dict):
                                page = meta.get("PAGE_NUMBER", "N/A")
                                path = meta.get("RELATIVE_PATH", "N/A")
                                print(f"  • Page {page} – {path}")

            else:
                # Fallback if agent returns string or another type
                print(f"\nAgent: {response}")

        except KeyboardInterrupt:
            print("\nExiting interactive session.")
            break
        except Exception as e:
            print(f"⚠️ An error occurred: {e}")

if __name__ == "__main__":
