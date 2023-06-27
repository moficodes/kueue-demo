#!/bin/sh
kubectl create -f quick-job.yaml
kubectl create -f all-or-nothing-job-1.yaml
kubectl create -f all-or-nothing-job-2.yaml