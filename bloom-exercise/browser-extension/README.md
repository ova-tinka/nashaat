# Bloom browser extension work

`lib/domain-policy.mjs` is the shared browser-side domain matching foundation. It is not a browser extension package: there is no manifest, communication channel, background worker, or released browser coverage yet. Do not distribute it or represent any browser as protected by this code.

The label-boundary matching approach is adapted from Focuser commit `14cbfdb3d55d3bc669bc9a39a6eddb9915e61844`; its MIT notice is in `FOCUSER-LICENSE`. Bloom deliberately retains subdomain-specific rules and does not import Focuser's wildcard, path, keyword, or full-internet features. Native and browser implementations run the same domain coverage vectors in `tests/fixtures/macos-domain-policy.json`.
