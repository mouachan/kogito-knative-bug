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