#!/usr/bin/env bash

REMOTE_HOST=stackbuilders@xxx.xxx.xxx.xxx
GIT_REMOTE_NAME=production
DEPLOY_TARGET=/var/projects/stackbuilders-${GIT_REMOTE_NAME}
GIT_REMOTE_URL=${REMOTE_HOST}:stackbuilders.${GIT_REMOTE_NAME}.git

# Circle CI deploys for us. We don't want to just push HEAD since that
# may or may not have been tested. Instead, push the exact SHA that
# was built.
if [[ -z "$CIRCLE_SHA1" ]]
  then
    echo CIRCLE_SHA1 must be defined!
    exit 1
fi

# Only add the git remote if it doesn't exist.
if [ `git remote -v | grep ${GIT_REMOTE_NAME} | wc -l` -eq 0 ]
  then
    git remote add ${GIT_REMOTE_NAME} ${GIT_REMOTE_URL}
  else
    echo Git remote already exists, proceeding to push.
fi

git push ${GIT_REMOTE_NAME} --force ${CIRCLE_SHA1}:refs/heads/master

if [ $? -eq 0 ]; then
    echo Push to ${GIT_REMOTE_NAME} succeeded, proceeding to build...

    # Deploys, rebuilding all dependencies in the sandbox.
    ssh ${REMOTE_HOST} <<EOF
      cd ${DEPLOY_TARGET} &&\
      git fetch --all &&\
      git reset --hard origin/master &&\
      rm -rf .cabal-sandbox &&\
      cabal sandbox init &&\
      cabal clean &&\
      cabal update &&\
      cabal install --only-dependencies -j &&\
      cabal build -j &&\
      cabal install &&\
      sudo /etc/init.d/sb-app restart
EOF

else
    echo Code push to ${GIT_REMOTE_NAME} failed!
    exit 1
fi
