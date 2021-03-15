
To reproduce the bug on openshift:

install from Operator hub
 -  kogito operator
 -  serveless (knative serving and eventing)
```sh
 cat <<-EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
 name: knative-serving
---
apiVersion: operator.knative.dev/v1alpha1
kind: KnativeServing
metadata:
    name: knative-serving
    namespace: knative-serving
EOF
```
```sh
cat <<-EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
    name: knative-eventing
---
apiVersion: operator.knative.dev/v1alpha1
kind: KnativeEventing
metadata:
    name: knative-eventing
    namespace: knative-eventing
EOF
```

 oc label namespace kogito-knative-bug bindings.knative.dev/include=true

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


```
build and deploy kogito service
```sh
cd ../eligibility
mvn clean package -DskipTests=true 
oc start-build eligibility --from-dir=target
```

call the eligibility service
```sh
curl -X POST \
-H "content-type: application/json"  \
-H "ce-specversion: 1.0"  \
-H "ce-source: /from/localhost"  \
-H "ce-type: eligibilityapplication" \
-H "ce-id: 12346"  \
-d "{\"age\":3,\"amount\":50000,\"bilan\":{\"gg\":5,\"ga\":2,\"hp\":1,\"hq\":2,\"dl\":50,\"ee\":2,\"siren\":\"423646512\",\"variables\":[]},\"ca\":200000,\"eligible\":false,\"msg\":\"string\",\"nbEmployees\":10,\"notation\":{\"decoupageSectoriel\":0,\"note\":\"string\",\"orientation\":\"string\",\"score\":0,\"typeAiguillage\":\"string\"},\"publicSupport\":true,\"siren\":\"423646512\",\"typeProjet\":\"IRD\"}" \
http://eligibility-kogito-knative-bug.apps.ocp4.ouachani.org 
```

log the cloudevent-display service
```sh
oc logs -l serving.knative.dev/service=cloudevent-display -c user-container --tail=-1                                                                                           19:32:27
K_SINK env : http://broker-ingress.kogito-knative-bug.svc.cluster.local/kogito-knative-bug/default
Server started on port 8080
Error while decoding the event: io.cloudevents.rw.CloudEventRWException: Invalid extensions name: kogitoprocessinstanceid
```

