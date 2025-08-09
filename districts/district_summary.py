from langchain_aws import ChatBedrock
from html2text import html2text
import pandas as pd

OFFICE_SLUG = {
    "State Representative": "state-rep",
    "State Senate": "state-senate",
    "Governor's Council": "gov-council",
    "U.S. House": "us-house",
}

def main():
    df = pd.read_csv("ma_legislative_district_info.csv")
    dist_md = df.apply(
        lambda x: district_page_md(x["office"], x["district"]),
        axis=1,
    )
    messages_lists = [query_messages(md) for md in dist_md]
    model = ChatBedrock(
        model="us.anthropic.claude-3-7-sonnet-20250219-v1:0",
    )
    responses = model.batch(messages_lists)
    df["summary"] = [resp.content for resp in responses]
    df.to_csv("ma_leg_dists_w_summary.csv", index=False)
    
def district_slug(district_name):
    slug = (district_name
            .lower()
            .replace(" ", "-")
            .replace("&", "and")
            .replace(",", ""))
    return slug

def district_page_md(office_name, district_name):
    office_slug = OFFICE_SLUG[office_name]
    dist_slug = district_slug(district_name)
    html_file_name = (
        f"../docs/districts/{office_slug}/{dist_slug}.html"
    )
    with open(html_file_name) as f:
        html_text = f.read()
    md_text = html2text(html_text)
    return md_text

def query_messages(md_text):
    messages = [
        {
            "role": "system",
            "content": "Provide a brief one or two sentence summary of this Massachusetts legislative district including the information on the incumbent and the location of the district in plain text with no heading.",
        },
        {
            "role": "human",
            "content": md_text,
        },
    ]
    return messages
    
if __name__ == "__main__":
    main()
