#!/usr/bin/env bash

    # tag prefixes
export PRODUCTION_BRANCH_TAG="production"

export MASTER_BRANCH_TAG="master"
export MASTER_IMAGE_TAG="test"

export FEATURE_TAG_POSTFIX="-feature"
export RELEASE_TAG_POSTFIX="-release"
export HOTFIX_TAG_POSTFIX="-hotfix"
export BUGFIX_TAG_POSTFIX="-bugfix"
export SUPPORT_TAG_POSTFIX="-support"

# Build
export TAG=`if [ "$TRAVIS_BRANCH" == "$MASTER_BRANCH_TAG" ]; then
      echo "$MASTER_IMAGE_TAG";
    elif [ "$TRAVIS_BRANCH" == "$PRODUCTION_BRANCH_TAG" ]; then
        echo "$PRODUCTION_BRANCH_TAG";
    elif [[ "$TRAVIS_BRANCH" =~ ^feature/ ]]; then
        name=$(echo $TRAVIS_BRANCH | cut -f2-3 -d "/" | sed 's|/|-|')
        echo "${name}$FEATURE_TAG_POSTFIX";
    elif [[ "$TRAVIS_BRANCH" =~ ^release/ ]]; then
        name=$(echo $TRAVIS_BRANCH | cut -f2-3 -d "/" | sed 's|/|-|')
        echo "$name$RELEASE_TAG_POSTFIX";
    elif [[ "$TRAVIS_BRANCH" =~ ^hotfix/ ]]; then
        name=$(echo $TRAVIS_BRANCH | cut -f2-3 -d "/" | sed 's|/|-|')
        echo "${name}$HOTFIX_TAG_POSTFIX";
    elif [[ "$TRAVIS_BRANCH" =~ ^bugfix/ ]]; then
        name=$(echo $TRAVIS_BRANCH | cut -f2-3 -d "/" | sed 's|/|-|')
        echo "${name}$BUGFIX_TAG_POSTFIX";
    elif [[ "$TRAVIS_BRANCH" =~ ^support/ ]]; then
        name=$(echo $TRAVIS_BRANCH | cut -f2-3 -d "/" | sed 's|/|-|')
        echo "${name}$SUPPORT_TAG_POSTFIX";
    else
        echo $TRAVIS_BRANCH ;
    fi`
export IMAGE_NAME=${DOCKER_HUB_REPO}${MODULE}:${TAG}
docker build --no-cache -t ${IMAGE_NAME} .
docker login -u="$DOCKER_USERNAME" -p="$DOCKER_PASSWORD"
docker push ${IMAGE_NAME}
