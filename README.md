
To reproduce the bug on openshift:

install from Operator hub
 -  kogito operator
 -  serveless (knative serving and eventing)
deploy the broker
```sh
oc create -f - <<EOF
apiVersion: eventing.knative.dev/v1
kind: broker
metadata:
  name: default
EOF
```
get the url of the broker

```sh
oc get broker     
NAME      URL                                                                                   AGE   READY   REASON
default   http://broker-ingress.knative-eventing.svc.cluster.local/kogito-knative-bug/default   59m   True 
```

deploy cloudevent-display knative service to catch cloudevents (use your own broker url)
```sh
oc create -f - <<EOF
# simple knative application to display the routed messages
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: cloudevent-display
spec:
  template:
    spec:
      containers:
        - env:
            - name: K_SINK
              value: >-
                http://broker-ingress.knative-eventing.svc.cluster.local/kogito-knative-bug/default
          image: registry.hub.docker.com/mouachani/cloudevent-display
EOF
```

deploy the trigger 
```sh
oc create -f - <<EOF
apiVersion: eventing.knative.dev/v1
kind: Trigger
metadata:
  name: display-all-events-trigger
spec:
  # The default Broker is enabled in the namespace.
  broker: default
  # The subscriber is the deployed displayer service. Any event that matches the filter in the Broker is sent here.
  subscriber:
    ref:
      apiVersion: serving.knative.dev/v1
      kind: Service
      name: cloudevent-display
EOF
```
deploy the kogito infra
```sh
oc create -f - <<EOF
apiVersion: app.kiegroup.org/v1beta1
kind: KogitoInfra
metadata:
  name: kogito-knative-infra
spec:
  # Bind Knative Broker to the service
  resource:
    apiVersion: eventing.knative.dev/v1
    kind: Broker
    name: default
EOF
```
build the model
```sh
cd model
mvn clean install
```
create kogito service eligibility
```sh
oc create -f - <<EOF
apiVersion: app.kiegroup.org/v1beta1
kind: KogitoBuild
metadata:
  name: eligibility
spec:
  type: Binary
 # type: RemoteSource
 # gitSource:
 #   contextDir: /eligibility
  #  uri: "https://github.com/mouachan/bbank-apps"
  #webHooks:
  #  - type: "GitHub"
  #    secret: "github"
  # set your maven nexus repository to speed up the build time
  #mavenMirrorURL:
---
apiVersion: app.kiegroup.org/v1beta1
kind: KogitoRuntime
metadata:
  annotations:
    org.kie.kogito/managed-by: Kogito Operator
    org.kie.kogito/operator-crd: KogitoRuntime
    prometheus.io/path: /metrics
    prometheus.io/port: "8080"
    prometheus.io/scheme: http
    prometheus.io/scrape: "true"
  labels:
    app: eligibility
    eligibility: process
  name: eligibility
spec:
  serviceLabels:
    app: eligibility
  infra:
    - kogito-knative-infra
EOF
```
build and deploy kogito service
```sh
cd ../eligibility
mvn clean package -DskipTests=true 
oc start-build eligibility --from-dir=target
```

call the eligibility service
```sh
curl -X POST \                                                                                                                                                                  19:24:37
-H "content-type: application/json"  \
-H "ce-specversion: 1.0"  \
-H "ce-source: /from/localhost"  \
-H "ce-type: eligibilityapplication" \
-H "ce-id: 12346"  \
-d "{\"age\":3,\"amount\":50000,\"bilan\":{\"gg\":5,\"ga\":2,\"hp\":1,\"hq\":2,\"dl\":50,\"ee\":2,\"siren\":\"423646512\",\"variables\":[]},\"ca\":200000,\"eligible\":false,\"msg\":\"string\",\"nbEmployees\":10,\"notation\":{\"decoupageSectoriel\":0,\"note\":\"string\",\"orientation\":\"string\",\"score\":0,\"typeAiguillage\":\"string\"},\"publicSupport\":true,\"siren\":\"423646512\",\"typeProjet\":\"IRD\"}" \
http://eligibility-kogito-knative-bug.apps.cluster-389f.389f.example.opentlc.com
```

log the cloudevent-display service
```sh
oc logs -l serving.knative.dev/service=cloudevent-display -c user-container --tail=-1                                                                                           19:32:27
K_SINK env : http://broker-ingress.kogito-knative-bug.svc.cluster.local/kogito-knative-bug/default
Server started on port 8080
Error while decoding the event: io.cloudevents.rw.CloudEventRWException: Invalid extensions name: kogitoprocessinstanceid
```

