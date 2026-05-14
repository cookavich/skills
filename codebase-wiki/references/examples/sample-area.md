# Auth

Authentication, session lifecycle, and API key validation for the public billing API.

## Responsibility

- Validate incoming credentials (email/password, OAuth tokens, API keys).
- Mint and verify short-lived session JWTs; rotate refresh tokens.
- Enforce per-route scope and tenant isolation via middleware.

## Key files

- `src/auth/index.ts` — public exports (single barrel).
- `src/auth/strategies.ts:14-58` — password and OAuth strategy implementations.
- `src/auth/session.ts:22-90` — JWT mint/verify; rotates refresh tokens.
- `src/auth/middleware/require-scope.ts` — Express middleware enforcing scope claims.
- `src/auth/repos/api-key.ts` — API-key lookup with constant-time compare.

## Public interfaces

```
authenticate(req)               -> Session | AuthError
authorize(session, scope)       -> Authorized | Forbidden
mintAccessToken(userId, scope)  -> AccessToken
verifyAccessToken(token)        -> Claims | Invalid
```

Routes registered in `src/api/routes/auth.ts`:

| Method | Path | Handler |
|--------|------|---------|
| POST | `/auth/login` | `loginHandler` |
| POST | `/auth/refresh` | `refreshHandler` |
| POST | `/auth/logout` | `logoutHandler` |

## Internal flow

```
Client request with credentials
  -> src/api/routes/auth.ts:loginHandler
    -> src/auth/strategies.ts:validatePassword
      -> src/auth/repos/user.ts:findByEmail
    -> src/auth/session.ts:mintAccessToken
    -> src/auth/session.ts:mintRefreshToken
      -> src/auth/repos/refresh-token.ts:store
  <- 200 { access, refresh }
```

## Dependencies

**Upstream (auth depends on):**

- `src/db/` — user and refresh-token repositories
- `src/lib/crypto/` — bcrypt wrapper, JWT signing
- `src/config/` — JWT secrets and expiry windows

**Downstream (depends on auth):**

- `src/api/middleware/` — every protected route uses `requireScope`
- `src/billing/` — checks per-tenant scope before charging
- `src/admin/` — uses elevated `admin:*` scopes

## Tests

- `src/auth/__tests__/strategies.test.ts` — unit tests for each strategy.
- `src/auth/__tests__/session.test.ts` — JWT roundtrip, expiry, rotation.
- `tests/integration/auth-flow.test.ts:42-200` — end-to-end login → refresh → logout.

## Common changes

- **Add a new auth strategy** (e.g. SSO provider): create `src/auth/strategies/<name>.ts`, register in `src/auth/strategies.ts:registerStrategies`, add provider config to `src/config/auth.ts`.
- **Add a new scope**: declare in `src/auth/scopes.ts`, apply via `requireScope('your:scope')` middleware on the protected route.
- **Change token expiry**: edit `src/config/auth.ts` — `ACCESS_TOKEN_TTL` (15min default), `REFRESH_TOKEN_TTL` (7d default).

## Open questions

- Refresh-token rotation in `src/auth/session.ts:75` returns a new refresh token on every use; the old one is *not* immediately invalidated. May be intentional (to tolerate concurrent requests) but warrants confirmation.

---

Back to [README](../README.md) · Related: [API](../areas/api.md) · [Data Flow](../data-flow.md)
