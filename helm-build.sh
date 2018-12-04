#!/bin/bash

echo "============================================="
echo "==        HELM BUILD TOOL                  =="
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
    echo "SHORT_GIT_HASH: ${SHORT_GIT_HASH}"
    echo "DD_EVENT_VERSION: ${DD_EVENT_VERSION}"
    echo "DD_METRIC_VERSION: ${DD_METRIC_VERSION}"
    echo "DD_ROLE_TAG: ${DD_ROLE_TAG}" 
    echo "DD_API_KEY: ${DD_API_KEY}" 
    echo "DD_APP_KEY: ${DD_APP_KEY}"
    echo "DD_ENABLED: ${DD_ENABLED}"
    echo "QUAY_USERNAME: ${QUAY_USERNAME}"
    echo "QUAY_PASSWORD: ${QUAY_PASSWORD}"
    echo "IMAGE_NAME: ${IMAGE_NAME}"
    echo "=============================="
}

print_error(){
    echo "$1 environment variable is empty. Exit (1)"
    exit 1
}

report_event(){
    local title text image_tag version_tag status_tag role_tag alert_type
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
            --image_tag)
                image_tag=${2}
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
        \"tags\": [\"status:${status_tag}\", \"role:${role_tag}\", \"image:${image_tag}\", \"version:${version_tag}\"],
        \"alert_type\": \"${alert_type}\"
    }" \
    $DD_STREAM_URL
}

report_counter_metric(){
    local image_tag version_tag status_tag role_tag

    if [ -z "$DD_ENABLED" ] || [ "$DD_ENABLED" = false ];
    then
        echo "Warning: Datadog streaming is disabled."
        return
    fi    

    while [[ ${1} ]]; do
        case "${1}" in
            --image_tag)
                image_tag=${2}
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
            --metric_name)
                role_tag=${2}
                shift
                ;;   
            --metric_type)
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
            [{\"metric\":\"sentinelsix.build.count\",
            \"points\":[[$currenttime, 1]],
            \"type\":\"count\",
            \"host\":\"release.circleci\",
            \"tags\":[\"status:${status_tag}\", \"role:${role_tag}\", \"image:${image_tag}\", \"version:${version_tag}\"]}
            ]
    }" \
    $DD_SERIES_URL
}

report_elapsed_metric(){
    local image_tag version_tag status_tag role_tag elapsed_time

    if [ -z "$DD_ENABLED" ] || [ "$DD_ENABLED" = false ];
    then
        echo "Warning: Datadog streaming is disabled."
        return
    fi    

    while [[ ${1} ]]; do
        case "${1}" in
            --image_tag)
                image_tag=${2}
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
            [{\"metric\":\"sentinelsix.build.elapsed_time\",
            \"points\":[[$currenttime, $elapsed_time]],
            \"type\":\"gauge\",
            \"host\":\"release.circleci\",
            \"tags\":[\"status:${status_tag}\", \"role:${role_tag}\", \"image:${image_tag}\", \"version:${version_tag}\"]}
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
        --title "Sentinelsix Build Tag: ${SHORT_GIT_HASH} Build: ${RELEASE_NAME} (Success)" \
        --text "Build Tag ${SHORT_GIT_HASH}" \
        --image_tag $IMAGE_NAME \
        --version_tag $DD_EVENT_VERSION \
        --status_tag $STATUS_TAG_FAILURE \
        --role_tag $DD_ROLE_TAG \
        --alert_type $ALERT_TYPE_FAILURE

        # Report to Datadog a successful release
        report_counter_metric \
        --image_tag $IMAGE_NAME \
        --version_tag $DD_METRIC_VERSION \
        --status_tag $STATUS_TAG_FAILURE \
        --role_tag $DD_ROLE_TAG

        exit $exit_status
    fi
}
 
pre_validation(){
    # Validation Phase    
    if [ -z "$QUAY_USERNAME" ]
    then
        print_error "QUAY_USERNAME"
    fi

    if [ -z "$QUAY_PASSWORD" ]
    then
        print_error "QUAY_PASSWORD"
    fi

    if [ -z "$IMAGE_NAME" ]
    then
        print_error "IMAGE_NAME"
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

    if [ -z "$DD_API_KEY" ]
    then
        print_error "DD_API_KEY"
    fi      

    if [ -z "$DD_APP_KEY" ]
    then
        print_error "DD_APP_KEY"
    fi     
}

# Pre-validation
print_environment
pre_validation

start_time=$(date +'%s')

# Report to Datadog the release event
report_event \
--title "Sentinelsix Build Tag: ${SHORT_GIT_HASH} Build: ${RELEASE_NAME} (Info)" \
--text "Build ${RELEASE_NAME} Tag: ${SHORT_GIT_HASH}" \
--image_tag $IMAGE_NAME \
--version_tag $DD_EVENT_VERSION \
--status_tag $STATUS_TAG_INFO \
--role_tag $DD_ROLE_TAG \
--alert_type $ALERT_TYPE_INFO

if [ -z "$CIRCLE_SHA1" ]; then
    echo "Using latest version docker tag"
    $SHORT_GIT_HASH="latest"
else
    SHORT_GIT_HASH=$(echo $CIRCLE_SHA1 | cut -c -7)
fi

docker login quay.io -u $QUAY_USERNAME -p $QUAY_PASSWORD
error_checker $?

docker build -t $IMAGE_NAME:$SHORT_GIT_HASH .
error_checker $?

docker push $IMAGE_NAME:$SHORT_GIT_HASH
error_checker $?

end_time=$(date +'%s')
elapsed_time=$(($end_time - $start_time))

echo "====================================================="
echo "Build took $elapsed_time seconds.                    "
echo "====================================================="

# Stream success
report_event \
--title "Sentinelsix Build Tag: ${SHORT_GIT_HASH} Build: ${RELEASE_NAME} (Success)" \
--text "Build Tag ${SHORT_GIT_HASH}" \
--image_tag $IMAGE_NAME \
--version_tag $DD_EVENT_VERSION \
--status_tag $STATUS_TAG_SUCCESS \
--role_tag $DD_ROLE_TAG \
--alert_type $ALERT_TYPE_SUCCESS

# Report to Datadog a successful release
report_counter_metric \
--image_tag $IMAGE_NAME \
--version_tag $DD_METRIC_VERSION \
--status_tag $STATUS_TAG_SUCCESS \
--role_tag $DD_ROLE_TAG

# Report to Datadog elapsed build time
report_elapsed_metric \
--image_tag $IMAGE_NAME \
--version_tag $DD_METRIC_VERSION \
--status_tag $STATUS_TAG_SUCCESS \
--role_tag $DD_ROLE_TAG \
--elapsed_time $elapsed_time