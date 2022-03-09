#/bin/bash

# todo:
## create one true cluster admin
## create X fake users
## load-test + aggregation of results
## remove all pvcs.
## remove all users.
TEST_VARIABLES_FILE=test-variables.yml

fakeadmin=$(yq  e '.OCP_ADMIN_USER.USERNAME' ./test-variables.yml)
fakeadminpass=$(yq  e '.OCP_ADMIN_USER.PASSWORD' ./test-variables.yml)

fakeadmin="${fakeadmin:-fakeadmin}"
fakeadminpass="${fakeadminpass:-fakeadminpass}"

fakeuser="${fakeuser:-ldapuser}"
# fakeuserpass=$(yq  e '.TEST_USER.PASSWORD' ./test-variables.yml)
fakeuserpass="userpass"
fakeuserpass="${fakeuserpass:-fakepass}"


# htpasswd -c -B -b htpasswd.txt ${fakeadmin} ${fakeadminpass} > /dev/null 2>&1
# for i in {0..600};
# do
#    htpasswd  -B -b htpasswd.txt ${fakeuser}$i ${fakeuserpass} > /dev/null 2>&1
# done

## if we have yq installed
# if command -v yq &> /dev/null
# then
#     echo "we found yq"

#     ## get the user, pass and API hostname for OpenShift
#     oc_user=$(yq  e '.OCP_ADMIN_USER.USERNAME' ${TEST_VARIABLES_FILE})
#     oc_pass=$(yq  e '.OCP_ADMIN_USER.PASSWORD' ${TEST_VARIABLES_FILE})
#     oc_host=$(yq  e '.OCP_API_URL' ${TEST_VARIABLES_FILE})

#     ## do an oc login here
#     oc login "${oc_host}" --username "${oc_user}" --password "${oc_pass}"

#     ## no point in going further if the login is not working
#     retVal=$?
#     if [ $retVal -ne 0 ]; then
#         echo "The oc login command seems to have failed"
#         echo "Please review the content of ${TEST_VARIABLES_FILE}"
#         exit $retVal
#     fi
#     oc cluster-info
#     printf "\nconnected as openshift user ' $(oc whoami) '\n"
#     echo "since the oc login was successful, continuing."

#     # update the content of the secret:
#     oc create secret generic htpasswd-secret \
#         --from-file=htpasswd=htpasswd.txt \
#         --dry-run=client -o yaml -n openshift-config \
#         | oc apply -f -

#     ## force a rollout of the Auth
#     oc -n openshift-authentication \
#         rollout restart deployment oauth-openshift

# else
#     echo "we did not find yq, so not trying the oc login"
# fi


function runfakeuser(){
    mkdir -p ./test-output/${fakeuser}$1
    cp ./test-variables.yml ./test-output/${fakeuser}$1/var.yml

    export fake="ldapuser${1}"
    export fakeuserpass="userpass"

    yq e -i '
        .TEST_USER.USERNAME = strenv(fake)  |
        .TEST_USER.PASSWORD = strenv(fakeuserpass)
        ' ./test-output/${fakeuser}$1/var.yml

    # podman run --rm -d \
    # podman run --rm -it \
    podman run --rm  -it \
        -v $PWD/test-output/${fakeuser}$1/var.yml:/tmp/ods-ci/test-variables.yml:Z \
        -v $PWD/test-output/${fakeuser}$1:/tmp/ods-ci/test-output:Z \
        -v $PWD/tests/Tests:/tmp/ods-ci/tests/App:Z \
        -e RUN_SCRIPT_ARGS='--test-case tests/App/500__jupyterhub/test-jupyterlab-cpu-stresstest.robot'  \
        ods-ci:v5
}

# for i in {4..5};
# do
#     runfakeuser $i &
# done

runfakeuser 5 &
sleep 3
runfakeuser 7 &
sleep 3
runfakeuser 8 &
sleep 3
runfakeuser 9 &


## remember to clean out all the PVCs at the end.
# for i in {001..040};
# do
#     oc -n rhods-notebooks get pvc jupyterhub-nb-fakeuser$i-pvc
#     oc -n rhods-notebooks delete pvc jupyterhub-nb-fakeuser$i-pvc
# done

# and clean out the users too.

# oc get pvc -n rhods-notebooks --no-headers=true     | awk '/jupyterhub-nb-/{print $1}'    | xargs oc delete -n rhods-notebooks pvc