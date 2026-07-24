# Grounded RAG on Azure AI Search

**Track:** AI Platform · **Level:** Advanced · **Time:** ~50 min · **Cost:** free AI Search tier + a fraction of a cent for embeddings/answers
**Status:** Authored — pending one real end-to-end certification run before publish.
**Full walkthrough (illustrated):** https://azure.campux.co/lab-rag-azure-ai-search

> Run in **Azure Cloud Shell (Bash)**. The **Free** AI Search tier includes vector search at no charge.

## Scenario

Retrieval-augmented generation makes a model answer from *your* documents instead of its imagination. Build the whole pipeline over a Campux knowledge base, get cited answers, and prove the hardest part: it **refuses** to answer what it cannot find.

## Résumé line

*"Implemented a retrieval-augmented generation pipeline on Azure AI Search with Azure OpenAI embeddings, returning grounded, cited answers and refusing out-of-corpus questions."*

## Files

- `ingest.py` — chunk, embed, and upload documents to a vector index.
- `ask.py` — embed a question, vector-search, and answer only from retrieved chunks.
- `requirements.txt`

## Steps

```bash
cd lab-rag-azure-ai-search
RG="campux-lab-rag-rg"
az group create -n "$RG" -l eastus

# free-tier AI Search (one per subscription, includes vector search)
SEARCH="campuxsearch$RANDOM"
az search service create -n "$SEARCH" -g "$RG" --sku free -l eastus
export SEARCH_ENDPOINT="https://$SEARCH.search.windows.net"
export SEARCH_KEY=$(az search admin-key show --service-name "$SEARCH" -g "$RG" --query primaryKey -o tsv)

# Azure OpenAI + embeddings model + small chat model
AOAI="campuxaoai$RANDOM"
az cognitiveservices account create -n "$AOAI" -g "$RG" -l eastus2 --kind OpenAI --sku S0 --custom-domain "$AOAI" --yes
az cognitiveservices account deployment create -g "$RG" -n "$AOAI" --deployment-name text-embedding-3-small --model-name text-embedding-3-small --model-version 1 --model-format OpenAI --sku-name Standard --sku-capacity 1
az cognitiveservices account deployment create -g "$RG" -n "$AOAI" --deployment-name gpt-4o-mini --model-name gpt-4o-mini --model-version 2024-07-18 --model-format OpenAI --sku-name Standard --sku-capacity 1
export AOAI_ENDPOINT=$(az cognitiveservices account show -n "$AOAI" -g "$RG" --query properties.endpoint -o tsv)
export AOAI_KEY=$(az cognitiveservices account keys list -n "$AOAI" -g "$RG" --query key1 -o tsv)

pip install --quiet azure-search-documents openai
python ingest.py                                            # -> indexed 3 documents
python ask.py "Can I return oat milk I bought yesterday?"   # -> grounded, cited answer
python ask.py "What is the Wi-Fi password at the Camden store?"  # -> Not found in the Campux documents.
```

✅ **Checkpoints:** an in-corpus question returns a cited answer; an off-corpus question returns exactly `Not found in the Campux documents.`

## Teardown

```bash
az group delete -n campux-lab-rag-rg --yes
```

> **Gotcha:** model deployments are region- and version-sensitive. If a deployment is refused, recreate the Azure OpenAI resource in `swedencentral` or `eastus`.
