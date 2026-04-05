# Celeste Semantic Search

Search the codebase by concept using Celeste's MinHash-based semantic search. Finds functions related to a concept even if they don't contain the exact search term.

## Instructions

Call the celeste MCP tool with the user's search query:

```json
{
  "prompt": "Use code_search to find symbols semantically related to: '<USER_QUERY>'. Return the top 10 results with similarity scores, file locations, and signatures.",
  "mode": "chat",
  "workspace": "$CWD"
}
```

Replace `$CWD` with the current working directory and `<USER_QUERY>` with the user's search terms.

Then read the top 3-5 results yourself (using Read tool) to provide context about what they do.

## Examples

- "authentication session handling" — finds auth middleware, session validators, token managers
- "error recovery retry" — finds retry loops, circuit breakers, fallback handlers
- "database connection pool" — finds pool configs, connection factories, health checks

## How It Works

Celeste's code graph stores MinHash signatures (128 hashes) for every symbol, computed from function names, parameter types, body identifiers, package names, and doc comments. Search computes Jaccard similarity between the query and every symbol's signature.
