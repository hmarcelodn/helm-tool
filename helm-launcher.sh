#!/bin/bash

echo "============================================="
echo "==        HELM RELEASE TOOL                =="
echo "============================================="
echo ""

# Globals
DD_SERIES_URL="https://api.datadoghq.com/api/v1/series?api_key=${DD_API_KEY}"
DD_STREAM_URL="https://api.datadoghq.com/api/v1/events?api_key=${DD_API_KEY}"
STATUS_TAG_FAILURE="failure"
STATUS_TAG_SUCCESS="success"
STATUS_TAG_INFO="info"
ALERT_TYPE_INFO="info"
ALERT_TYPE_SUCCESS="success"
ALERT_TYPE_FAILURE="error"

# Setup terminal to exit script on error
set -e

# Functions
print_environment(){
    echo "=============================="
    echo "    ENVIRONMENT VARIABLES     "
    echo "=============================="
    echo "- RELEASE_NAME: ${RELEASE_NAME}"
    echo "- RELEASE_NAMESPACE: ${RELEASE_NAMESPACE}"
    echo "- HELM_VALUES_S3_FOLDER: ${HELM_VALUES_S3_FOLDER}"
    echo "- HELM_CHART_NAME: ${HELM_CHART_NAME}"
    echo "- HELM_VALUES_FILENAME: ${HELM_VALUES_FILENAME}"
    echo "- HELM_VALUES_BASE_ON: ${HELM_VALUES_BASE_ON}"
    echo "- SHORT_GIT_HASH: ${SHORT_GIT_HASH}"
    echo "- DD_EVENT_VERSION: ${DD_EVENT_VERSION}"
    echo "- DD_METRIC_VERSION: ${DD_METRIC_VERSION}"
    echo "- DD_ROLE_TAG: ${DD_ROLE_TAG}"
    echo "- DD_ENVIRONMENT_TAG: ${DD_ENVIRONMENT_TAG}"
    echo "- DD_API_KEY: ${DD_API_KEY}"
    echo "- DD_APP_KEY: ${DD_APP_KEY}"
    echo "- DD_ENABLED: ${DD_ENABLED}"
    echo "=============================="
}

print_error(){
    echo "$1 environment variable is empty. Exit (1)"
    exit 1
}

report_event(){
    local title text environment_tag release_tag version_tag status_tag role_tag alert_type
    local priority="normal"

    if [ -z "$DD_ENABLED" ] || [ "$DD_ENABLED" = false ];
    then
        echo "Warning: Datadog streaming is disabled."
        return
    fi    

    while [[ ${1} ]]; do
        case "${1}" in
            --title)
                title=${2}
                shift
                ;;
            --text)
                text=${2}
                shift
                ;;
            --environment_tag)
                environment_tag=${2}
                shift
                ;; 
            --release_tag)
                release_tag=${2}
                shift
                ;; 
            --version_tag)
                version_tag=${2}
                shift
                ;;   
            --status_tag)
                status_tag=${2}
                shift
                ;;  
            --role_tag)
                role_tag=${2}
                shift
                ;;   
            --alert_type)
                alert_type=${2}
                shift
                ;;
            *)
                echo "Unknown parameter: ${1}" >&2
                return 1
        esac

        if ! shift; then
            echo 'Missing parameter argument.' >&2
            return 1
        fi
    done

    # Check alert_type
    if [ $alert_type != "info" ] && [ $alert_type != "warning" ] && [ $alert_type != "success" ] &&  [ $alert_type != "error" ]; then
        echo "Invalid alert_type"
        exit 1
    fi

    curl  -X POST \
    -H "Content-type: application/json" \
    -d "{
        \"title\": \"${title}\",
        \"text\": \"${text}\",
        \"priority\": \"${priority}\",
        \"tags\": [\"environment:${environment_tag}\", \"status:${status_tag}\", \"role:${role_tag}\", \"release:${release_tag}\", \"version:${version_tag}\"],
        \"alert_type\": \"${alert_type}\"
    }" \
    $DD_STREAM_URL
}

report_counter_metric(){
    local environment_tag release_tag version_tag status_tag role_tag

    if [ -z "$DD_ENABLED" ] || [ "$DD_ENABLED" = false ];
    then
        echo "Warning: Datadog streaming is disabled."
        return
    fi

    while [[ ${1} ]]; do
        case "${1}" in
            --environment_tag)
                environment_tag=${2}
                shift
                ;;
            --release_tag)
                release_tag=${2}
                shift
                ;;
            --version_tag)
                version_tag=${2}
                shift
                ;;
            --status_tag)
                status_tag=${2}
                shift
                ;;
            --role_tag)
                role_tag=${2}
                shift
                ;;
            *)
                echo "Unknown parameter: ${1}" >&2
                return 1
        esac

        if ! shift; then
            echo 'Missing parameter argument.' >&2
            return 1
        fi
    done

    currenttime=$(date +%s)

    curl  -X POST -H "Content-type: application/json" \
    -d "{ \"series\" :
            [{\"metric\":\"sentinelsix.release.count\",
            \"points\":[[$currenttime, 1]],
            \"type\":\"count\",
            \"host\":\"release.circleci\",
            \"tags\":[\"environment:${environment_tag}\", \"status:${status_tag}\", \"role:${role_tag}\", \"release:${release_tag}\", \"version:${version_tag}\"]}
            ]
    }" \
    $DD_SERIES_URL
}

report_elapsed_metric(){
    local environment_tag release_tag version_tag status_tag role_tag elapsed_time

    if [ -z "$DD_ENABLED" ] || [ "$DD_ENABLED" = false ];
    then
        echo "Warning: Datadog streaming is disabled."
        return
    fi

    while [[ ${1} ]]; do
        case "${1}" in
            --environment_tag)
                environment_tag=${2}
                shift
                ;;
            --release_tag)
                release_tag=${2}
                shift
                ;;
            --version_tag)
                version_tag=${2}
                shift
                ;;
            --status_tag)
                status_tag=${2}
                shift
                ;;
            --role_tag)
                role_tag=${2}
                shift
                ;;
            --elapsed_time)
                elapsed_time=${2}
                shift
                ;;
            *)
                echo "Unknown parameter: ${1}" >&2
                return 1
        esac

        if ! shift; then
            echo 'Missing parameter argument.' >&2
            return 1
        fi
    done   

    currenttime=$(date +%s)

    curl  -X POST -H "Content-type: application/json" \
    -d "{ \"series\" :
            [{\"metric\":\"sentinelsix.release.elapsed_time\",
            \"points\":[[$currenttime, $elapsed_time]],
            \"type\":\"gauge\",
            \"host\":\"release.circleci\",
            \"tags\":[\"environment:${environment_tag}\", \"status:${status_tag}\", \"role:${role_tag}\", \"release:${release_tag}\", \"version:${version_tag}\"]}
            ]
    }" \
    $DD_SERIES_URL
}

error_checker(){
    local exit_status=$1
    if [ $exit_status -ne 0 ]; then
        echo "Error detected: ${exit_status}"

        # Stream success
        report_event \
        --title "Sentinelsix Release Tag: ${SHORT_GIT_HASH} Release: ${RELEASE_NAME} (Success)" \
        --text "Release Tag ${SHORT_GIT_HASH}" \
        --environment_tag $DD_ENVIRONMENT_TAG \
        --release_tag $RELEASE_NAME \
        --version_tag $DD_EVENT_VERSION \
        --status_tag $STATUS_TAG_FAILURE \
        --role_tag $DD_ROLE_TAG \
        --alert_type $ALERT_TYPE_FAILURE

        # Report to Datadog a successful release
        report_counter_metric \
        --environment_tag $DD_ENVIRONMENT_TAG \
        --release_tag $RELEASE_NAME \
        --version_tag $DD_METRIC_VERSION \
        --status_tag $STATUS_TAG_FAILURE \
        --role_tag $DD_ROLE_TAG

        exit $exit_status
    fi
}

pre_validation(){
    if [ -z "$RELEASE_NAME" ]
    then
        print_error "RELEASE_NAME"
    fi

    if [ -z "$RELEASE_NAMESPACE" ]
    then
        print_error "RELEASE_NAMESPACE"
    fi

    if [ -z "$HELM_VALUES_S3_FOLDER" ]
    then
        print_error "HELM_VALUES_S3_FOLDER"
    fi

    if [ -z "$HELM_CHART_NAME" ]
    then
        print_error "HELM_CHART_NAME"
    fi

    if [ -z "$HELM_VALUES_FILENAME" ]
    then
        print_error "HELM_VALUES_FILENAME"
    fi

    if [ -z "$HELM_VALUES_BASE_ON" ]
    then
        print_error "HELM_VALUES_BASE_ON"
    fi

    if [ -z "$DD_EVENT_VERSION" ]
    then
        print_error "DD_EVENT_VERSION"
    fi

    if [ -z "$DD_METRIC_VERSION" ]
    then
        print_error "DD_METRIC_VERSION"
    fi

    if [ -z "$DD_ROLE_TAG" ]
    then
        print_error "DD_ROLE_TAG"
    fi

    if [ -z "$DD_ENVIRONMENT_TAG" ]
    then
        print_error "DD_ENVIRONMENT_TAG"
    fi

    if [ -z "$DD_API_KEY" ]
    then
        print_error "DD_API_KEY"
    fi

    if [ -z "$DD_APP_KEY" ]
    then
        print_error "DD_APP_KEY"
    fi
}

# Validation
print_environment
pre_validation

start_time=$(date +'%s')

# Report to Datadog the release event
report_event \
--title "Sentinelsix Release Tag: ${SHORT_GIT_HASH} Release: ${RELEASE_NAME} (Info)" \
--text "Release ${RELEASE_NAME} Tag: ${SHORT_GIT_HASH}" \
--environment_tag $DD_ENVIRONMENT_TAG \
--release_tag $RELEASE_NAME \
--version_tag $DD_EVENT_VERSION \
--status_tag $STATUS_TAG_INFO \
--role_tag $DD_ROLE_TAG \
--alert_type $ALERT_TYPE_INFO

# Release Phase

echo ""
echo "Configuring Helm Package Manager"
echo "================================"
helm init --client-only
error_checker $?
helm plugin install https://github.com/hypnoglow/helm-s3.git || true
helm repo add s6 s3://s6-kubernetes-charts
error_checker $?
helm repo update
error_checker $?

echo ""
echo "Downloading ${HELM_VALUES_FILENAME} from S3"
echo "==========================================="
aws s3 cp s3://s6-kubernetes-values/$HELM_VALUES_S3_FOLDER/$HELM_VALUES_FILENAME $HELM_VALUES_FILENAME
error_checker $?

RELEASE="${RELEASE_NAME}"
DEPLOYS=$(helm ls --namespace $RELEASE_NAMESPACE | grep $RELEASE | wc -l)

if [ -z "$CIRCLE_SHA1" ]; then
    echo "Using latest version docker tag"
    $SHORT_GIT_HASH="latest"
else
    SHORT_GIT_HASH="$(echo $CIRCLE_SHA1 | cut -c -7)"
fi

if [ "$HELM_VALUES_BASE_ON" = true ]; then
    echo "Using base.yaml file"
    aws s3 cp s3://s6-kubernetes-values/$HELM_VALUES_S3_FOLDER/base.yaml base.yaml
fi

echo ""
echo "Listing filesystem for debugging purposes"
echo "========================================="
ls -lah

if [ ${DEPLOYS}  -eq 0 ]; then
    echo ""
    echo "Installing release ${RELEASE}"
    echo "============================="

    if [ "$HELM_VALUES_BASE_ON" = false ]; then
        helm install --name $RELEASE s6/$HELM_CHART_NAME -f $HELM_VALUES_FILENAME --set image.tag=$SHORT_GIT_HASH --namespace $RELEASE_NAMESPACE
        error_checker $?
    else
        helm install --name $RELEASE s6/$HELM_CHART_NAME -f base.yaml -f $HELM_VALUES_FILENAME --set image.tag=$SHORT_GIT_HASH --namespace $RELEASE_NAMESPACE
        error_checker $?
    fi
else
    echo ""
    echo "Upgrading release ${RELEASE}"
    echo "============================"

    if [ "$HELM_VALUES_BASE_ON" = false ]; then
        helm upgrade $RELEASE s6/$HELM_CHART_NAME -f $HELM_VALUES_FILENAME --set image.tag=$SHORT_GIT_HASH --namespace $RELEASE_NAMESPACE --recreate-pods
        error_checker $?
    else
        helm upgrade $RELEASE s6/$HELM_CHART_NAME -f base.yaml -f $HELM_VALUES_FILENAME --set image.tag=$SHORT_GIT_HASH --namespace $RELEASE_NAMESPACE --recreate-pods
        error_checker $?
    fi
fi

end_time=$(date +'%s')
elapsed_time=$(($end_time - $start_time))

echo "====================================================="
echo "Deployment took $elapsed_time seconds."
echo "====================================================="

# Stream success
report_event \
--title "Sentinelsix Release Tag: ${SHORT_GIT_HASH} Release: ${RELEASE_NAME} (Success)" \
--text "Release Tag ${SHORT_GIT_HASH}" \
--environment_tag $DD_ENVIRONMENT_TAG \
--release_tag $RELEASE_NAME \
--version_tag $DD_EVENT_VERSION \
--status_tag $STATUS_TAG_SUCCESS \
--role_tag $DD_ROLE_TAG \
--alert_type $ALERT_TYPE_SUCCESS

# Report to Datadog a successful release
report_counter_metric \
--environment_tag $DD_ENVIRONMENT_TAG \
--release_tag $RELEASE_NAME \
--version_tag $DD_METRIC_VERSION \
--status_tag $STATUS_TAG_SUCCESS \
--role_tag $DD_ROLE_TAG

# Report to Datadog elapsed release time
report_elapsed_metric \
--environment_tag $DD_ENVIRONMENT_TAG \
--release_tag $RELEASE_NAME \
--version_tag $DD_METRIC_VERSION \
--status_tag $STATUS_TAG_SUCCESS \
--role_tag $DD_ROLE_TAG \
--elapsed_time $elapsed_time