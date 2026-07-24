import os
from azure.core.credentials import AzureKeyCredential
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    SearchIndex, SimpleField, SearchableField, SearchField,
    SearchFieldDataType, VectorSearch, HnswAlgorithmConfiguration, VectorSearchProfile)
from openai import AzureOpenAI

SE, SK = os.environ["SEARCH_ENDPOINT"], os.environ["SEARCH_KEY"]
oai = AzureOpenAI(api_key=os.environ["AOAI_KEY"], api_version="2024-10-21",
                  azure_endpoint=os.environ["AOAI_ENDPOINT"])
INDEX = "campux-kb"

DOCS = [
    ("returns", "Campux Retail accepts returns within 30 days with a receipt. Perishable goods such as oat milk are non-returnable."),
    ("hours",   "The Camden store opens at 07:00 and closes at 20:00 on weekdays. Shoreditch opens at 08:00 and closes at 22:00."),
    ("loyalty", "The Campux loyalty card earns one point per pound spent. 100 points can be redeemed for a free coffee."),
]


def embed(text):
    return oai.embeddings.create(model="text-embedding-3-small", input=text).data[0].embedding


fields = [
    SimpleField(name="id", type=SearchFieldDataType.String, key=True),
    SearchableField(name="content", type=SearchFieldDataType.String),
    SearchField(name="vector", type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
                searchable=True, vector_search_dimensions=1536,
                vector_search_profile_name="hnsw-profile"),
]
vs = VectorSearch(
    algorithms=[HnswAlgorithmConfiguration(name="hnsw")],
    profiles=[VectorSearchProfile(name="hnsw-profile", algorithm_configuration_name="hnsw")])
SearchIndexClient(SE, AzureKeyCredential(SK)).create_or_update_index(
    SearchIndex(name=INDEX, fields=fields, vector_search=vs))

docs = [{"id": i, "content": t, "vector": embed(t)} for i, t in DOCS]
SearchClient(SE, INDEX, AzureKeyCredential(SK)).upload_documents(docs)
print(f"indexed {len(docs)} documents into {INDEX}")
