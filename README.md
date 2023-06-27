# Kueue Demo

## Setup Cluster

```bash
gcloud container clusters create "kueue" --zone "us-central1-c" --release-channel "regular" --machine-type "n2-standard-2" --num-nodes "2"
```

```bash
gcloud container node-pools create "spot" --cluster "kueue" --zone "us-central1-c" --machine-type "n2-standard-2" --spot --num-nodes "2"
```
## Install Kueue

```bash
VERSION=v0.3.2
kubectl apply -f https://github.com/kubernetes-sigs/kueue/releases/download/$VERSION/manifests.yaml
```

```bash
kubectl api-resources | grep kueue
```

## Deploy Kueue Resources

```bash
kubectl apply -f kueue-resource.yaml
```

This will create 3 Kueue resources:
    1. Resource Flavor
    2. Cluster Queue
    3. Local Queue

```bash
kubectl apply -f job-1.yaml -f job-2.yaml
```

```bash
kubectl get po -o wide
```

We will see we are using both node pools for these workload. We also start scheduling both jobs at the same time.

## Resource Flavor with Selctor

We may want to have specific workload run on specific hardware. Thats where resource flavors with nodelabels come in.

We create 2 different resource flavor for on demand and spot VMs. We then create a cluster queue for each resource flavor.

```bash
kubectl apply -f resource-flavors.yaml
kubectl apply -f cluster-queue.yaml
kubectl apply -f local-queue.yaml
```

Lets create some job on the on demand pool.

```bash
kubectl create -f job-2-on-demand-lq.yaml
```

```bash
kubectl get po -o wide
```

We will see all of the pods are scheduled on the on demand pool. Now lets create some load on the on demand pool and see how our pool handles it.

```bash
while true; do kubectl create -f job-2-on-demand-lq.yaml; sleep 3; done
```

We are creating a new job every 2 second. We have a total of 16Gb of memory. Each job is requesting roughly 3Gb of memory. So we can have 5 of these jobs running at the same time. Kueue will only let these 5 jobs to be scheduled. It is using kubernetes job suspend feature to acheive this.

```bash
kubectl get clusterqueue -o wide
```

We will see the cluster queue has more and more pending jobs.

## Cohorts

In Kueue we have a concept of Cohorts to be able to share resources. All clusterqueue in the same cohort can share their resources as if they are in the same queue.

```bash
kubectl apply -f cluster-queue-cohort.yaml
```

By default clusterqueues in the same cohort can borrow 100% of each others resources. We can change this by setting the `borrowLimit` field in the cohort.

```bash
while true; do kubectl create -f job-2-on-demand-lq.yaml; sleep 1; done
```

If we create some load on the spot pool those jobs will take priority over the on demand jobs. Borrowing of resources is only allowed if the cluster queue has resources to spare.

```bash
while true; do kubectl create -f job-2-spot-lq.yaml; sleep 4; done
```

We can see that the spot jobs are taking priority over the on demand jobs.

## All or nothing scheduling

There are certain workloads that requires all of its pods to be scheduled before work can begin. In Kueue we can have it setup to do all or nothing scheduling. At this time its a global setting. So if you have kueue installed with this configuration it is all-or-nothing for all workload.

Without all or nothing scheduling we can end up in a situation where we hit deadlock. Where we have 2 jobs that are waiting for each other to finish before they can start. This is a common problem in distributed systems.

```bash
./deadlock.sh
```

```bash
kubectl apply -f configmap.yaml
```

Delete the existing kueue controller so the new changes are picked up.

```bash
kubectl delete po -n kueue-system --all
```

After the controller is up and running we can try to recreate the deadlock again. This time we will see that the deadlock is resolved.

```bash
./deadlock.sh
``` 

## Cleanup

```bash
gcloud container clusters delete kueue --zone us-central1-c
```
