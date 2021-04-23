
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
                http://broker-ingress.knative-eventing.svc.cluster.local/kogito-knative/default
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
create kogito services eligibility and notation
```sh
oc apply -f ../manifest/eligibility-kogitoapp.yml
oc apply -f ../manifest/notation-kogitoapp.yml
```
build and deploy eligibility service
```sh
cd ../eligibility
mvn clean package -DskipTests=true 
oc start-build eligibility --from-dir=target
```
```
export ELIGIBILITY_ROUTE=http://$(oc get route eligibility  --template={{.spec.host}})
echo $ELIGIBILITY_ROUTE
http://eligibility-kogito-knative-bug.apps.cluster-2ab3.2ab3.sandbox777.opentlc.com
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
$ELIGIBILITY_ROUTE
```

log the cloudevent-display service
```sh
oc logs -l serving.knative.dev/service=cloudevent-display -c user-container --tail=-1
☁️  cloudevents.Event
Validation: valid
Context Attributes,
  specversion: 1.0
  type: noteapplication
  source: /process/eligibility
  id: 8146dbe6-a61f-438f-a3b2-d2f4850f201d
  time: 2021-04-15T04:35:06.308822Z
Extensions,
  knativearrivaltime: 2021-04-15T04:35:06.311561176Z
  kogitoprocid: eligibility
  kogitoprocinstanceid: 9c8af898-0ea2-4e3a-8d13-62fe96e209e8
  kogitousertaskist: 1
Data,
  {"siren":"423646512","ca":200000.0,"nbEmployees":10.0,"age":3,"publicSupport":true,"typeProjet":"IRD","amount":50000.0,"notation":{"score":0.0,"note":"string","orientation":"string","decoupageSectoriel":0.0,"typeAiguillage":"string"},"eligible":true,"msg":"Eligible","bilan":{"siren":"423646512","gg":5.0,"ga":2.0,"hp":1.0,"hq":2.0,"hn":0.0,"fl":0.0,"fm":0.0,"dl":50.0,"ee":2.0,"variables":[]},"rate":0.0,"nbmonths":0}
```

build and deploy notation service
```sh
cd ../notation
mvn clean package -DskipTests=true 
oc start-build notation --from-dir=target
```
get the notation route
```
export NOTATION_ROUTE=http://$(oc get route notation  --template={{.spec.host}})
echo $NOTATION_ROUTE
http://notation-kogito-knative-bug.apps.cluster-2ab3.2ab3.sandbox777.opentlc.com
```

call the notation service
```sh
curl -X POST \
-H "content-type: application/json"  \
-H "ce-specversion: 1.0"  \
-H "ce-source: /from/localhost"  \
-H "ce-type: noteapplication" \       
-H "ce-id: 12346"  \
-d "{\"age\":3,\"amount\":50000,\"bilan\":{\"gg\":5,\"ga\":2,\"hp\":1,\"hq\":2,\"dl\":50,\"ee\":2,\"siren\":\"423646512\",\"variables\":[]},\"ca\":200000,\"eligible\":false,\"msg\":\"string\",\"nbEmployees\":10,\"notation\":{\"decoupageSectoriel\":0,\"note\":\"string\",\"orientation\":\"string\",\"score\":0,\"typeAiguillage\":\"string\"},\"publicSupport\":true,\"siren\":\"423646512\",\"typeProjet\":\"IRD\"}" \
$NOTATION_ROUTE 


log the cloudevent-display service
```sh
oc logs -l serving.knative.dev/service=cloudevent-display -c user-container --tail=-1
  ☁️  cloudevents.Event
Validation: valid
Context Attributes,
  specversion: 1.0
  type: model1
  source: /process/notation
  id: 0486172c-3e18-426e-89fb-388499c600dc
  time: 2021-04-15T04:45:09.976501Z
Extensions,
  knativearrivaltime: 2021-04-15T04:45:09.979059835Z
  kogitoprocid: notation
  kogitoprocinstanceid: 9b4c4cdd-089b-4163-8748-557154e1577d
  kogitousertaskist: 1
Data,
  {"score":0.0,"note":"A","orientation":"Approved","decoupageSectoriel":1.0,"typeAiguillage":"MODELE_1"}
```  
