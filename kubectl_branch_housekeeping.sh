#!/bin/bash

# Grab all pod names that have DeadlineExceeded which means job has expired.
DEAD_JOB_PODS=$(kubectl get pods | grep "DeadlineExceeded" | awk '{print $1}')

SAVEIFS=$IFS # Save current IFS
IFS=$'\n' # Change IFS to new line
DEAD_JOB_PODS_ARR=($DEAD_JOB_PODS) # split to array
IFS=$SAVEIFS # Restore IFS

if [ -z "$PATTERN" ]; then
    echo "No PATTERN found, exiting early."
    exit 1
fi

if [ -z "$DEAD_JOB_PODS" ]; then
    echo "No dead job pods found to cleanup, exiting early"
fi

for (( i=0; i<${#DEAD_JOB_PODS_ARR[@]}; i++ ))
do
    DIRTY_NAME=${DEAD_JOB_PODS_ARR[$i]}
    
    echo "Found $DIRTY_NAME, proceeding to cleaning up name."

    if [ -z "$DIRTY_NAME" ]; then
        echo "No DIRTY_NAME found, exiting early."
        exit 1
    fi

    if [[ $DIRTY_NAME == *"-job"* ]]; then
        echo "Found 'job' in DIRTY_NAME, not doing replace magic"
        CLEAN_NAME=${DIRTY_NAME%-job*}
    else
        echo "'job' was not found in DIRTY_NAME, checking for '$PATTERN' and doing replace magic if exist."
        if [[ $DIRTY_NAME != *"-$PATTERN"* ]]; then
            echo "No '$PATTERN' found, cannot proceed".
            exit 1
        else
            CLEAN_NAME=${DIRTY_NAME%-$PATTERN*}
            CLEAN_NAME=$CLEAN_NAME-$PATTERN
        fi
    fi

    if [ -z "$CLEAN_NAME" ]; then
        echo "No CLEAN_NAME found, exiting early."
        exit 1
    fi

    echo "Name cleaned to: $CLEAN_NAME, now deleting defunct job/ingress/service from k8s."

    kubectl delete deployment --ignore-not-found=true --force --grace-period=0 $CLEAN_NAME
    kubectl delete service -l app=$CLEAN_NAME --ignore-not-found=true --force --grace-period=0
    kubectl delete all,ing -l app=$CLEAN_NAME --ignore-not-found=true --force --grace-period=0
done
