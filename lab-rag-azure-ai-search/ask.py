import os, sys
from azure.core.credentials import AzureKeyCredential
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from openai import AzureOpenAI

SE, SK = os.environ["SEARCH_ENDPOINT"], os.environ["SEARCH_KEY"]
oai = AzureOpenAI(api_key=os.environ["AOAI_KEY"], api_version="2024-10-21",
                  azure_endpoint=os.environ["AOAI_ENDPOINT"])
q = sys.argv[1]

qvec = oai.embeddings.create(model="text-embedding-3-small", input=q).data[0].embedding
sc = SearchClient(SE, "campux-kb", AzureKeyCredential(SK))
hits = sc.search(search_text=None, select=["id", "content"],
                 vector_queries=[VectorizedQuery(vector=qvec, k_nearest_neighbors=3, fields="vector")])
context = "\n".join(f"[{h['id']}] {h['content']}" for h in hits)

prompt = (
    "Answer the question using ONLY the context below. "
    "Cite the source id in square brackets. "
    "If the answer is not in the context, reply exactly: "
    "'Not found in the Campux documents.'\n\n"
    f"Context:\n{context}\n\nQuestion: {q}")
ans = oai.chat.completions.create(model="gpt-4o-mini",
        messages=[{"role": "user", "content": prompt}], temperature=0)
print(ans.choices[0].message.content)
