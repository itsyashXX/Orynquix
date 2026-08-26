# MagicCipher Studio V6

Full-stack TypeScript cipher workbench.

## V6
- Recursive Magic search with Fast / Balanced / Deep budgets
- Configurable Magic peel depth up to 12
- Layer Stack: 1-100 repeated encryption/decryption rounds
- Cyclic custom layer recipes
- Portable `MC5L` layered token stores the recipe (never secret keys)
- Automatic reverse-order layer decryption for MC5L tokens
- Direct Vigenere, Caesar, ROT13, ROT47, Atbash, Base64, Hex, URL, XOR and AES-256-GCM
- Multilingual evidence scoring and ranked results
- Vercel serverless API routes

## Run
```bash
npm install
npm run dev
```

## Build
```bash
npm run build
```


## V6 adaptive analysis
V6 adds adaptive beam search, cipher-family estimates, Base32/decimal/octal/Bacon/Rail-Fence candidates, larger deep-search budgets, and a Continue Deeper UX. Unresolved inputs are reported as `No reliable plaintext yet` rather than an unhelpful unknown state.
