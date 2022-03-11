# ODS-CI Container Image

A [Dockerfile](Dockerfile) is available for running tests in a container.
The latest build can be downloaded from: https://quay.io/odsci/ods-ci:latest

eg: podman pull quay.io/odsci/ods-ci:latest

```bash
## I assume you have yq.
## get oc from your own cluster

oc_url="$(yq  e '.OCP_CONSOLE_URL' ./test-variables.yml \
    | sed 's/console\-/downloads\-/g' )/amd64/linux/oc.tar" ; echo $oc_url

curl --insecure -L ${oc_url} \
  -o - | tar xf - > ./oc

# Build the container (optional if you dont want to use the latest from quay.io/odsci)
podman build -t ods-ci:v4 -f build/Dockerfile .

# create the output directory
$ mkdir -p $PWD/test-output

user=$(yq  e '.OCP_ADMIN_USER.USERNAME' ./test-variables.yml)
pass=$(yq  e '.OCP_ADMIN_USER.PASSWORD' ./test-variables.yml)
auth=$(yq  e '.OCP_ADMIN_USER.AUTH_TYPE' ./test-variables.yml)
host=$(yq  e '.OCP_API_URL' ./test-variables.yml)

podman run --rm -it \
    --entrypoint oc \
    -v ${PWD}/kubeconfig:/tmp/.kube/config:Z \
    ods-ci:master \
    login "${host}" \
        --username "${user}" \
        --password "${pass}"

# Mount a file volume to provide a test-variables.yml file at runtime
# Mount a volume to preserve the test run artifacts
# Run all tests
$ podman run --rm \
    -v $PWD/test-variables.yml:/tmp/ods-ci/test-variables.yml:Z \
    -v $PWD/test-output:/tmp/ods-ci/test-output:Z \
    ods-ci:master

# Run a single test
# use the image as-is.
podman run --rm -it \
    -v $PWD/test-variables.yml:/tmp/ods-ci/test-variables.yml:Z \
    -v $PWD/test-output:/tmp/ods-ci/test-output:Z \
    -e RUN_SCRIPT_ARGS='--test-case tests/Tests/500__jupyterhub/test-jupyterlab-git-notebook.robot'  \
    ods-ci:v4

# a new test I'm working on:
podman run --rm -it \
    -v $PWD/test-variables.yml:/tmp/ods-ci/test-variables.yml:Z \
    -v $PWD/test-output:/tmp/ods-ci/test-output:Z \
    -e RUN_SCRIPT_ARGS='--test-case tests/Tests/500__jupyterhub/test-jupyterlab-cpu-stresstest.robot'  \
    ods-ci:v4

# if you want to run a new test without having re-built the image, just mount it:
podman run --rm -it \
    -v $PWD/test-variables.yml:/tmp/ods-ci/test-variables.yml:Z \
    -v $PWD/test-output:/tmp/ods-ci/test-output:Z \
    -v $PWD/tests/Tests/500__jupyterhub/test-jupyterlab-cpu-stresstest.robot:/tmp/ods-ci/tests/Tests/700/test.robot:Z \
    -e RUN_SCRIPT_ARGS='--test-case tests/Tests/700/test.robot'  \
    ods-ci:v4

# if you want to run a new test without having re-built the image, just mount it:
podman run --rm -it \
    -v $PWD/test-variables.yml:/tmp/ods-ci/test-variables.yml:Z \
    -v $PWD/test-output:/tmp/ods-ci/test-output:Z \
    -v $PWD/tests/Tests:/tmp/ods-ci/tests/App:Z \
    -e RUN_SCRIPT_ARGS='--test-case tests/App/500__jupyterhub/test-jupyterlab-cpu-stresstest.robot'  \
    ods-ci:v5




podman run --rm -it \
    -v $PWD/test-variables.yml:/tmp/ods-ci/test-variables.yml:Z \
    -v $PWD/test-output:/tmp/ods-ci/test-output:Z \
    -v $PWD/tests/Tests/500__jupyterhub/test-jupyterlab-cpu-stresstest.robot:/tmp/ods-ci/tests/Tests/700/test.robot:Z \
    --env RUN_SCRIPT_ARGS="--extra-robot-args '-i ODS-935'" \
    ods-ci:v4

podman run --rm -it \
    --entrypoint "./venv/bin/rebot" \
    -v $PWD/test-output:/tmp/ods-ci/test-output:Z \
    ods-ci:v4 \
    --name Combined \
    -d test-output/all/ \
    /tmp/ods-ci/test-output/*/output.xml

    --outputdir /tmp/ods-ci/test-output/all/















```


### Running the ods-ci container image in OpenShift

After building the container, you can deploy the container in a pod running on OpenShift. You can use [this](./ods-ci.pod.yaml) PersistentVolumeClaim and Pod definition to deploy the ods-ci container.  NOTE: This example pod attaches a PVC to preserve the test artifacts directory between runs and mounts the test-variables.yml file from a Secret.

```
# Creates a Secret with test variables that can be mounted in ODS-CI container
$ oc create secret generic ods-ci-test-variables --from-file test-variables.yml
```


### creating many loadtest users in podman

```
bash launch.many.podman.sh
```

## OpenShift.

### Push the image to quay

```bash
## pushing to my own quay repo. but it's public.
podman tag localhost/ods-ci:v4 quay.io/egranger/ods-ci:v4
podman push                    quay.io/egranger/ods-ci:v4
```

### Create project in openshift

```
oc create ns loadtest

```

#### create secret

```bash
oc -n loadtest delete secret ods-ci-test-variables

## default syntax for default var file:
oc -n loadtest create secret generic ods-ci-test-variables \
    --from-file test-variables.yml
## but if your var file is called something else:
oc -n loadtest create secret generic ods-ci-test-variables \
    --from-file=test-variables.yml=perf2-variables.yml

```


### define 1 job

```bash
oc -n loadtest delete -f ./build/ods-ci.job.yaml

## delete stray notebooks if any
oc get pods -n rhods-notebooks --no-headers=true \
    | awk '/ldapuser/{print $1}'\
    | xargs oc delete -n rhods-notebooks pod

oc -n loadtest apply -f ./build/ods-ci.job.yaml

```


### keeping the results around

TODO

```bash
stern -n loadtest ods-ci --since 15s -t -i 'PASS|FAIL' | tail /tmp/loadtest.results.txt
```
