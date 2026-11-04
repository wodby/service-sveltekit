# SvelteKit on Wodby

What this service adds to the Node.js service it is based on. It targets SvelteKit 3, which needs Node.js 22.17 or later; every Node.js version the service offers (22, 24, 26) qualifies.

## Build and start

The service's Dockerfile copies the build context to `/usr/src/app`, runs `npm run build` and starts the container with `npm run start`. `package.json` must define both scripts.

- The supported production output is `@sveltejs/adapter-node`: set `adapter: adapter()` in the `sveltekit()` plugin in `vite.config.ts`, build with `vite build` and start with `node build`. SvelteKit 3 reads its configuration from the `sveltekit()` Vite plugin; it does not read `svelte.config.js`.
- The Dockerfile does not install dependencies. The pipeline does it before the image is built (`wodby ci run -- npm ci`), and `node_modules` is copied with the code. `@sveltejs/kit`, the adapter, Vite and Svelte may stay in `devDependencies`: adapter-node bundles them into `build/`. Packages in `dependencies` are loaded from `node_modules` at runtime, which the image contains.
- `npm run build` runs while the image is built. Runtime variables of the service, including the link variables and secrets, are not available to it. See "Environment variables" for how to read them.
- The image build leaves out `.git`, `.gitignore`, `build` and `.svelte-kit`. The build creates `build/` and `.svelte-kit/` anew.
- The application must listen on port 3000. adapter-node listens on `PORT` and defaults to 3000; leave `PORT` unset.

## Environment variables

SvelteKit 3 reads environment variables declared in `src/env.ts` with `defineEnvVars` from `@sveltejs/kit/env`, and server code imports them from `$app/env/private`. The `$env/dynamic/*` and `$env/static/*` modules still work but are deprecated.

- Keep variables dynamic, the default. A variable with `static: true` is inlined at build time, when the service's runtime variables do not exist.
- SvelteKit validates the declared variables when the server starts and also during `vite build`. A variable declared without a `schema` must be set, so the image build fails. Give every runtime variable a schema that accepts a missing value, for example `schema: (value) => value || undefined`, or check `building` from `$app/env` in the schema and require the value only when it is false.
- Variables declared with `public: true` reach the browser through `$app/env/public`. Never mark a secret public.
- Server code may also read `process.env` at request time.

## Proxy, origin and form actions

Wodby's gateway terminates TLS, keeps the request's `Host` header and sets `X-Forwarded-Proto` and `X-Forwarded-For`. The service sets adapter-node's variables for that:

| Variable | Value | Effect |
| --- | --- | --- |
| `PROTOCOL_HEADER` | `x-forwarded-proto` | `url.origin` is the scheme the visitor used plus the `Host` header, so it is right for every domain of the environment. Requests without the header, such as checks inside the environment, are treated as `https`. |
| `ADDRESS_HEADER` | `x-forwarded-for` | `getClientAddress()` returns the visitor's address as the gateway recorded it. |
| `XFF_DEPTH` | `1` | Only the right-most `X-Forwarded-For` entry, which the gateway appends, is trusted. |
| `SHUTDOWN_TIMEOUT` | `25` | After `SIGTERM`, open requests get 25 seconds before their connections are closed, within the 30 second grace period. Then the `sveltekit:shutdown` process event runs. |

- SvelteKit 3 always checks the `Origin` header of form submissions (form actions and `POST`, `PUT`, `PATCH`, `DELETE` with a form content type) in production. The request's own origin passes, so every domain of the environment works. Do not set `paths.origin` in `vite.config.ts`: it is fixed at build time and allows only one domain. Use `csrf.trustedOrigins` only for other sites that must post to the application.
- `getClientAddress()` throws for a request without `X-Forwarded-For`, which is a request that did not pass the gateway, such as a check from inside the environment. Do not call it unconditionally in `handle` or in `/healthz`.
- Request bodies are limited to 512 KB by default. Set `BODY_SIZE_LIMIT` (for example `10M`, or `Infinity`) on the service for larger uploads.
- Do not set `HOST_HEADER`, `PORT_HEADER` or `ORIGIN`. SvelteKit 3's adapter-node no longer reads `ORIGIN`.

## Variables the service sets

| Variable | Meaning |
| --- | --- |
| `NODE_ENV` | `production` in every environment type, including `dev`. The Node.js service's `development` value for `dev` is replaced, because the container runs a production build. |
| `PROTOCOL_HEADER`, `ADDRESS_HEADER`, `XFF_DEPTH`, `SHUTDOWN_TIMEOUT` | See "Proxy, origin and form actions". |
| `WORKSPACE_NODE_COMMAND` | `workspace-node vite-start`, the start command of a development workspace. |

## Linked services

The service adds no link variables. The database, mail and Redis or Valkey variables of the Node.js service apply unchanged. Declare the ones the application uses in `src/env.ts` with a schema that accepts a missing value, because the links are optional and the variables do not exist during the build. They never reach the browser unless declared `public`.

## Health check

The boilerplate answers `GET /healthz` with `ok` from `src/routes/healthz/+server.ts`, without touching other services. Its post-deployment check requests `http://${WODBY_APP_SERVICE_NAME}:3000/healthz`.

## In a development workspace

- The application is started through Vite's JavaScript API with the project's own `vite.config.ts`, not through the `dev` script of `package.json`. Options in that script do not apply. Host, port, `strictPort` and file polling are set on top of the project's configuration, in memory; no file is written. `vite` must be a dependency of the project.
- The development server listens on `0.0.0.0:3000`. Do not change the port in the project configuration.
- Vite rejects requests for host names it does not know. Add the environment's hosts to `server.allowedHosts`: `WODBY_HOSTS` holds them as a JSON array, and `WODBY_APP_SERVICE_NAME` is the internal name. The boilerplate's `vite.config.ts` does this.
- File watching uses polling, so saved files and new route files are picked up without a restart. SvelteKit regenerates `.svelte-kit/`, including the `./$types` route types, while the development server runs. `npm ci` in the workspace's preparation runs the `prepare` script, `svelte-kit sync`, which creates it first.
- `NODE_ENV` is `development` here. The origin check of form submissions does not run in development.
- `/build/` and `/.svelte-kit/` are kept out of Git status, in addition to the Node.js service's paths.
- The image build's `npm run build` does not run in a workspace.
