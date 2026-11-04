# Node.js (SvelteKit) service for Kubernetes on Wodby

Build and run SvelteKit applications on Kubernetes with Wodby.

This repository defines the Wodby service manifests and operational
configuration for Node.js (SvelteKit).

- [Browse Wodby services](https://wodby.com/services)
- [Wodby service documentation](https://wodby.com/docs/2.0/services/)
- [Service manifest reference](https://wodby.com/docs/2.0/services/template/)

## Start with a boilerplate

Use one of the boilerplates exposed by this service to start with compatible
build configuration and Wodby CI:

- [SvelteKit Boilerplate](https://github.com/wodby/sveltekit-boilerplate)

## Wodby stacks using this service

- [SvelteKit application stack](https://github.com/wodby/stack-sveltekit)

## Service overview

| Property | Manifest configuration |
| --- | --- |
| Service name | `sveltekit` |
| Type | Application service |
| Inherits from | [`node`](https://github.com/wodby/service-node) with version constraint `^2.0.0` |
| Application build | Git source connection enabled; Dockerfile: `Dockerfile`; boilerplates: SvelteKit Boilerplate |

## Use this service

Use this service through [SvelteKit application stack](https://github.com/wodby/stack-sveltekit), or reference
`sveltekit` from a custom Wodby stack.

A service is a reusable component and does not deploy by itself. The stack
defines its links, settings, versions, resources, and relationship to the rest
of the application.

The image build runs `npm run build` and the container starts with
`npm run start`. Applications use SvelteKit 3 with the Node.js adapter
(`@sveltejs/adapter-node`) and start with `node build`. The service configures
the adapter for Wodby's gateway: the request scheme comes from
`X-Forwarded-Proto` and the client address from `X-Forwarded-For`, so form
actions work on every domain of an environment.

## Maintain a custom version

1. Fork this repository.
2. Edit the service manifest and referenced files.
3. Import the repository as a [Git-backed service](https://wodby.com/docs/2.0/services/create/#create-a-git-backed-service).
4. Reference the service from a stack manifest.

Keep service, workload, container, endpoint, link, volume, config, and
derivative names stable unless dependent stacks and app-level overrides are
updated at the same time.

Validate the manifests with:

```bash
wodby service validate-manifest service.yml --org <org-id> --include GUIDANCE.md
```

See the [service manifest reference](https://wodby.com/docs/2.0/services/template/) and the [managed services index](https://github.com/wodby/services).

## Workspace startup

Workspaces use `workspace-node vite-start`: Vite's development server starts
with the project's own Vite configuration, plus host, port and polling on
shared storage. SvelteKit's Vite plugin regenerates `.svelte-kit/` and route
types as files change. This command does not run custom `dev`, `predev` or
`postdev` scripts. Override `WORKSPACE_NODE_COMMAND` when those scripts are
required, and configure that command's watcher for shared storage. Add the
environment's hosts to `server.allowedHosts` in the Vite configuration.
Standard build/start behavior is unchanged. Requires a Node image with
workspace contract 1.
