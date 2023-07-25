## Deploy ECK on Kubernetes

In this guide we will install [ECK](https://www.elastic.co/guide/en/cloud-on-k8s/master/k8s-deploy-eck.html) on Kubernetes.

First of all install CRDs and ECK operator:

```
kubectl create -f https://download.elastic.co/downloads/eck/2.8.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.8.0/operator.yaml
```

Then we need to configure our Storage Class ([EFS CSI Driver with dynamic profisioning](https://github.com/kubernetes-sigs/aws-efs-csi-driver)) where elasticsearch will store and persist data:

```yaml
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: efs-eck-sc # Don't change this name since is used on eck-elastic.yml deloyment
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: <efs_id> # get the id form AWS console
  directoryPerms: "755"
  basePath: "/eck-storage-dynamic" # optional. Choose an appropriate name
```

Apply the above deployments and then we are ready to deploy elasticsearch:

```
kubectl apply -f https://raw.githubusercontent.com/garutilorenzo/k8s-aws-terraform-cluster/master/deployments/eck-elastic.yml
```

Check the status of the newly created pods, pv and pvc:

```
kubectl get pods
NAME                   READY   STATUS     RESTARTS   AGE
k8s-eck-es-default-0   0/1     Init:0/2   0          2s
k8s-eck-es-default-1   0/1     Init:0/2   0          2s
k8s-eck-es-default-2   0/1     Init:0/2   0          2s

root@i-097c1a2b2f1022439:~/eck# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                             STORAGECLASS   REASON   AGE
pvc-0d766371-f9a4-4210-abe5-077748808643   20Gi       RWO            Delete           Bound    default/elasticsearch-data-k8s-eck-es-default-0   efs-eck-sc              34s
pvc-6290aa54-f41b-4705-99fe-f69efddeb168   20Gi       RWO            Delete           Bound    default/elasticsearch-data-k8s-eck-es-default-1   efs-eck-sc              34s
pvc-e8e7a076-f8c3-4a93-8239-44b5ca8696fa   20Gi       RWO            Delete           Bound    default/elasticsearch-data-k8s-eck-es-default-2   efs-eck-sc              34s

root@i-097c1a2b2f1022439:~/eck# kubectl get pvc
NAME                                      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
elasticsearch-data-k8s-eck-es-default-0   Bound    pvc-0d766371-f9a4-4210-abe5-077748808643   20Gi       RWO            efs-eck-sc     35s
elasticsearch-data-k8s-eck-es-default-1   Bound    pvc-6290aa54-f41b-4705-99fe-f69efddeb168   20Gi       RWO            efs-eck-sc     35s
elasticsearch-data-k8s-eck-es-default-2   Bound    pvc-e8e7a076-f8c3-4a93-8239-44b5ca8696fa   20Gi       RWO            efs-eck-sc     35s
```

Wait until the elasticsearch pods are ready:

```
root@i-097c1a2b2f1022439:~/eck# kubectl get pods
NAME                   READY   STATUS    RESTARTS   AGE
k8s-eck-es-default-0   1/1     Running   0          3m3s
k8s-eck-es-default-1   1/1     Running   0          3m3s
k8s-eck-es-default-2   1/1     Running   0          3m3s
```

Now we can deploy Kibana with:

```
kubectl apply -f https://raw.githubusercontent.com/garutilorenzo/k8s-aws-terraform-cluster/master/deployments/eck-kibana.yml
```

Wait until kibana is up & running and check for the kibana service name:

```
root@i-097c1a2b2f1022439:~/eck# kubectl get pods
NAME                                 READY   STATUS    RESTARTS   AGE
k8s-eck-es-default-0                 1/1     Running   0          9m52s
k8s-eck-es-default-1                 1/1     Running   0          9m52s
k8s-eck-es-default-2                 1/1     Running   0          9m52s
k8s-eck-kibana-kb-56c4fb4bf8-vc9ct   1/1     Running   0          3m31s

kubectl get svc
NAME                       TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
k8s-eck-es-default         ClusterIP   None             <none>        9200/TCP   9m54s
k8s-eck-es-http            ClusterIP   10.107.103.161   <none>        9200/TCP   9m55s
k8s-eck-es-internal-http   ClusterIP   10.101.251.215   <none>        9200/TCP   9m55s
k8s-eck-es-transport       ClusterIP   None             <none>        9300/TCP   9m55s
k8s-eck-kibana-kb-http     ClusterIP   10.102.152.26    <none>        5601/TCP   3m34s
kubernetes                 ClusterIP   10.96.0.1        <none>        443/TCP    51m
```

Now create an ingress rule with the above deployment and apply it:

```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: eck-kibana-ingress
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  rules:
    - host: eck.yourdomain.com # FQDN in a domain that you manage. Create a CNAME record that point to the public LB DNS name
      http:
        paths:
          - pathType: Prefix
            path: /
            backend:
              service:
                name: k8s-eck-kibana-kb-http
                port:
                  number: 5601
```

Now apply filebeat and metricbeat deployments to get some data into elasticsearch:

```
kubectl apply -f https://raw.githubusercontent.com/garutilorenzo/k8s-aws-terraform-cluster/master/deployments/eck-filebeat.yml
kubectl apply -f https://raw.githubusercontent.com/garutilorenzo/k8s-aws-terraform-cluster/master/deployments/eck-metricbeat.yml
```

And wait that all the pods are ready:

```
root@i-097c1a2b2f1022439:~/eck# kubectl get pods
NAME                                       READY   STATUS    RESTARTS        AGE
k8s-eck-es-default-0                       1/1     Running   0               54m
k8s-eck-es-default-1                       1/1     Running   0               54m
k8s-eck-es-default-2                       1/1     Running   0               54m
k8s-eck-filebeat-beat-filebeat-76s9x       1/1     Running   4 (11m ago)     12m
k8s-eck-filebeat-beat-filebeat-pn77d       1/1     Running   4 (11m ago)     12m
k8s-eck-filebeat-beat-filebeat-wjkhm       1/1     Running   4 (11m ago)     12m
k8s-eck-kibana-kb-77d89694bc-vbp7s         1/1     Running   0               19m
k8s-eck-metricbeat-beat-metricbeat-8kpkl   1/1     Running   1 (7m36s ago)   8m1s
k8s-eck-metricbeat-beat-metricbeat-fl28t   1/1     Running   0               8m1s
k8s-eck-metricbeat-beat-metricbeat-knn2j   1/1     Running   1 (6m16s ago)   8m1s
```

Finally login to the Kibana UI on https://eck.yourdomain.com. Check [here](https://www.elastic.co/guide/en/cloud-on-k8s/master/k8s-deploy-kibana.html) how to get the elastic password.