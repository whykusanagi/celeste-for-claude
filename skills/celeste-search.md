# Celeste Semantic Search

Search the codebase by concept using Celeste's MinHash-based semantic search. Finds functions related to a concept even if they don't contain the exact search term — uses enriched shingles from function names, types, body identifiers, and comments.

## Instructions

The user will provide a search query (concept, not exact function name). Use the `celeste` MCP tool to delegate the search:

```json
{
  "prompt": "Use code_search to find symbols semantically related to: '<USER_QUERY>'. Show the top 10 results with similarity scores, file locations, and signatures. Then read the top 3 to provide context about what they do.",
  "mode": "agent",
  "workspace": "<current working directory>"
}
```

Replace `<USER_QUERY>` with the user's actual search terms.

## Examples

- "authentication session handling" — finds auth middleware, session validators, token managers
- "error recovery retry" — finds retry loops, circuit breakers, fallback handlers
- "database connection pool" — finds pool configs, connection factories, health checks

## How It Works

Celeste's code graph stores MinHash signatures (128 hashes) for every symbol, computed from:
- Split function/method names (camelCase → tokens)
- Parameter and return types
- Top 20 body identifiers by frequency
- Package name
- Doc comment keywords

Search computes Jaccard similarity between the query's shingles and every symbol's signature. Results above 5% similarity are returned, ranked by score.
