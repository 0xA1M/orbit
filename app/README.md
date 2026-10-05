# orbit app

Sanitized [Google microservices-demo](https://github.com/googlecloudplatform/microservices-demo) for orbit. Upstream pin in NOTICE.
Kept `src`, `protos`, `LICENSE`. All image and infra work is mine.

Image standard: no skaffold flags, pin image versions, nonroot user, keep WORKDIR and data files.

## changes from upstream

Deleted: `shoppingassistantservice/` folder, `frontend` `/assistant` page and `/bot` route plus handler, upstream `README.md`, all charts and manifests and terraform and CI folders during sanitize.
Added: `NOTICE` pin, `entrypoint.sh` in loadgenerator, `PORT` default in currencyservice and paymentservice, `USER` in every image missing it.
Flipped to opt-in: profiler in currencyservice, recommendationservice, emailservice and paymentservice, tracing and stats in shippingservice and adservice, stats in paymentservice path where present.
Frontend now needs 7 backends, not 8. Assistant routes are gone.

## map

| service | port | speaks | needs | talks to |
|---|---|---|---|---|
| productcatalogservice | 3550 | gRPC | nothing | no one, answers everyone |
| frontend | 8080 | HTTP | 7 addrs | catalog, currency, cart, recommendation, checkout, shipping, ad |
| checkoutservice | 5050 | gRPC | 6 addrs | shipping, catalog, cart, currency, email, payment |
| currencyservice | 7000 | gRPC | nothing | no one, answers frontend and checkout |
| cartservice | 7070 | gRPC | nothing, Redis optional | Redis or Spanner or AlloyDB or memory, answers frontend and checkout |
| recommendationservice | 8081 | gRPC | catalog addr | catalog, answers frontend |
| shippingservice | 50051 | gRPC + reflection | nothing | no one, answers frontend and checkout |
| paymentservice | 50052 | gRPC | nothing | no one, answers checkout |
| emailservice | 8082 | gRPC | nothing | no one, answers checkout |
| adservice | 9555 | gRPC | nothing | no one, answers frontend |
| loadgenerator | none | Locust HTTP client | FRONTEND_ADDR | frontend HTTP |

```text
frontend :8080
  -> catalog :3550
  -> checkout :5050 -> shipping, cart, currency, email, payment, catalog
  -> currency, cart, recommendation, shipping, ad
```

## productcatalogservice

Runs alone with no backends. I left the code as is and only cleaned the image. I dropped the skaffold debug flags and the traceback env, pinned distroless by digest, and added a nonroot user so it matches the rest.

| var | needed | default | note |
|---|---|---|---|
| PORT | no | 3550 | override listener |
| EXTRA_LATENCY | no | none | ex `100ms`, bad value kills it |
| ENABLE_TRACING | no | off | `1` needs collector below |
| COLLECTOR_SERVICE_ADDR | only with tracing | none | missing collector panics |
| DISABLE_PROFILER | no | profiler tries GCP | set to anything to turn it off |
| ALLOYDB_CLUSTER_NAME | no | local file | if set, switches to AlloyDB |
| PROJECT_ID | only with AlloyDB | none | required then |
| REGION | only with AlloyDB | none | required then |
| ALLOYDB_INSTANCE_NAME | only with AlloyDB | none | required then |
| ALLOYDB_DATABASE_NAME | only with AlloyDB | none | required then |
| ALLOYDB_TABLE_NAME | only with AlloyDB | none | required then |
| ALLOYDB_SECRET_NAME | only with AlloyDB | none | pulled from Secret Manager |

Tip: `SIGUSR1` turns catalog reload on, `SIGUSR2` turns it off. No restart needed.

## frontend

Dies fast without backends. I removed the whole assistant feature so it now needs 7 backends instead of 8. That meant deleting the addr field, the bot and assistant routes and handlers, and the assistant template. I also gave it the same image cleanup with pinned distroless and a nonroot user.

Required, every one (assistant cut 2026-09-30, now 7):

| var | example |
|---|---|
| PRODUCT_CATALOG_SERVICE_ADDR | catalog:3550 |
| CURRENCY_SERVICE_ADDR | currency:7000 |
| CART_SERVICE_ADDR | cart:7070 |
| RECOMMENDATION_SERVICE_ADDR | recommendation:8081 |
| CHECKOUT_SERVICE_ADDR | checkout:5050 |
| SHIPPING_SERVICE_ADDR | shipping:50051 |
| AD_SERVICE_ADDR | ad:9555 |

Optional:

| var | default | note |
|---|---|---|
| PORT | 8080 | override |
| LISTEN_ADDR | empty | empty means all interfaces |
| BASE_URL | empty | prefix for every route |
| ENABLE_TRACING | off | `1` needs collector below |
| COLLECTOR_SERVICE_ADDR | none | missing collector panics |
| ENABLE_PROFILER | off | `1` turns it on, opposite form from catalog |

## checkoutservice

Needs 6 backends or it panics on the first missing one. I did not touch the Go code here. I only cleaned the image the same way with no skaffold flags, pinned distroless, and a nonroot user.

| var | needed | default | note |
|---|---|---|---|
| SHIPPING_SERVICE_ADDR | yes | none | first checked, panics if missing |
| PRODUCT_CATALOG_SERVICE_ADDR | yes | none | required |
| CART_SERVICE_ADDR | yes | none | required |
| CURRENCY_SERVICE_ADDR | yes | none | required |
| EMAIL_SERVICE_ADDR | yes | none | required |
| PAYMENT_SERVICE_ADDR | yes | none | required |
| PORT | no | 5050 | override |
| ENABLE_TRACING | no | off | `1` needs collector |
| COLLECTOR_SERVICE_ADDR | only with tracing | none | required then |
| ENABLE_PROFILER | no | off | `1` turns it on |

## currencyservice

Node gRPC, standalone. Serves `Convert` and `GetSupportedCurrencies` from local ECB data. Ships a manual `client.js`, frontend never uses it. I added a `7000` port default so it starts empty handed, and I flipped the profiler from on by default to opt in because it crashed without a GCP project. The image got the same treatment with pinned digests and a nonroot user.

| var | needed | default | note |
|---|---|---|---|
| PORT | no | 7000 | my default, was required before |
| ENABLE_PROFILER | no | off | my flip, `1` turns GCP profiler on |
| ENABLE_TRACING | no | off | `1` needs collector below |
| COLLECTOR_SERVICE_ADDR | only with tracing | none | required then |
| OTEL_SERVICE_NAME | no | currencyservice | trace resource name |

## cartservice

C# gRPC with its Dockerfile nested under `src/`. It falls back to in memory storage when no Redis or cloud store is set, so it runs fine alone. I changed nothing here because it was already pinned and already nonroot.

| var | needed | default | note |
|---|---|---|---|
| REDIS_ADDR | no | memory | `host:port`, set for real cart persistence |
| SPANNER_PROJECT | no | unused | GCP path, leave unset |
| SPANNER_CONNECTION_STRING | no | unused | GCP path, leave unset |
| ALLOYDB_PRIMARY_IP | no | unused | GCP path, leave unset |
| ASPNETCORE_HTTP_PORTS | no | 7070 | set in image |

## recommendationservice

Python gRPC that calls the catalog to build recommendation lists. I flipped its profiler to opt in because the old default tried GCP on every start. I also added a nonroot user and kept the pinned base. It still requires the catalog addr or it raises.

| var | needed | default | note |
|---|---|---|---|
| PRODUCT_CATALOG_SERVICE_ADDR | yes | none | raises if empty |
| PORT | no | 8081 | override, moved from 8080 to end collision |
| ENABLE_PROFILER | no | off | my flip, set to turn GCP profiler on |
| ENABLE_TRACING | no | off | `1` needs collector |
| COLLECTOR_SERVICE_ADDR | only with tracing | localhost:4317 | defaults locally |

Dials catalog to build lists. Called by frontend. Guard verified: profiler and tracing off, then catalog-addr raise.

## shippingservice

Go gRPC with reflection on, so bare grpcurl works without a proto file. I flipped tracing, profiler and stats to opt in, removed the dead `APP_PORT` env that the code never read, pinned distroless, and added a nonroot user. It needs nothing to start and answers frontend and checkout.

| var | needed | default | note |
|---|---|---|---|
| PORT | no | 50051 | override |
| ENABLE_TRACING | no | off | set to enable, currently stubbed unavailable |
| ENABLE_PROFILER | no | off | my flip, set to enable |
| ENABLE_STATS | no | off | my flip, set to enable |

Standalone quote logic. Called by frontend and checkout. Test done: all three off, listening on 50051, SERVING without proto file thanks to reflection.

## paymentservice

Node gRPC that serves `Charge` for checkout. I gave it a `50051` default and fixed my own typo where I wrote a single pipe instead of a double pipe. I also flipped its profiler to opt in and added a nonroot user with pinned digests. It shares a port with shipping, so locally I run one at a time.

| var | needed | default | note |
|---|---|---|---|
| PORT | no | 50052 | my default, moved from 50051 to end collision |
| ENABLE_PROFILER | no | off | my flip, set to enable |
| ENABLE_TRACING | no | off | `1` needs collector |
| COLLECTOR_SERVICE_ADDR | only with tracing | none | required then |
| OTEL_SERVICE_NAME | no | paymentservice | trace resource name |

Serves `Charge`. Called by checkout, not frontend directly. Same `50051` as shipping, run one at a time locally. Test done: disabled logs, started, SERVING with proto file.

## emailservice

Python gRPC that only runs in dummy mode and just logs the confirmation. I flipped its profiler to opt in and added a nonroot user. It needs nothing to start and only checkout calls it. It shares `8080`, so locally I run one of the three at a time.

| var | needed | default | note |
|---|---|---|---|
| PORT | no | 8082 | override, moved from 8080 to end collision |
| ENABLE_PROFILER | no | off | my flip, set to enable |
| ENABLE_TRACING | no | off | `1` needs collector |
| COLLECTOR_SERVICE_ADDR | only with tracing | localhost:4317 | defaults locally |

Serves `SendOrderConfirmation` as a log line. Called by checkout only. Same `8080` as frontend and recommendation, run one at a time locally. Test done: dummy start, SERVING with proto file.

## adservice

Java gRPC with standalone ad logic that frontend calls. I flipped stats and tracing to opt in, kept the pinned Temurin images, and added a nonroot user. It needs nothing to start.

| var | needed | default | note |
|---|---|---|---|
| PORT | no | 9555 | override |
| ENABLE_STATS | no | off | my flip, set to enable |
| ENABLE_TRACING | no | off | my flip, set to enable |

Called by frontend only. Test done: stats and tracing off, listening on 9555, SERVING with proto file.

## loadgenerator

Locust HTTP client that hits the frontend, not a server so it has no port. I added a small entrypoint script with defaults for host and users and rate, fixed the file permissions order, and added a nonroot user. It starts clean and the failed requests just mean no frontend was running.

| var | needed | default | note |
|---|---|---|---|
| FRONTEND_ADDR | no | localhost:8080 | my default, was broken empty before |
| USERS | no | 10 | locust user count |
| RATE | no | 1 | spawn rate per second |

Hits frontend `/`, `/cart`, `/product/*`. Test done: starts Locust 2.43, ramps to 10 users, 100pct fails mean no frontend target running, script and defaults proven.
