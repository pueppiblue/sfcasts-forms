#!/usr/bin/env bash

# ${APP_ENVIRONMENT}
# => global env-var (introduced at build time, see Dockerfile)
# => could be overridden by runtime env-var
# add docker user (if not exist)

USER_EXIST=`id -u ${HOST_UID} > /dev/null 2>&1`
if [ $? = 1 ]; then
    groupadd --gid $HOST_GID $CONTAINER_GROUP
    useradd --uid $HOST_UID --gid $HOST_GID -ms /bin/bash $CONTAINER_USER

    echo "added system user: \"${CONTAINER_USER}\""
fi

bin/set_owner.sh
bin/set_acl.sh ${CONTAINER_USER}

##############################################################
# wait for es services to be available
##############################################################

# wait for mysql service to be available
until nc -z -v -w30 mysql 3306 > /dev/null 2>&1
do
    echo "Waiting for MySQL connection "
    sleep 5
done

if [ "${APP_ENVIRONMENT}" = "dev" ]; then
    gosu ${CONTAINER_USER} composer install --no-interaction
    gosu ${CONTAINER_USER} php bin/console assets:install --env=${APP_ENVIRONMENT}
elif [ "${APP_ENVIRONMENT}" = "test" ]; then
    gosu ${CONTAINER_USER} php bin/console cache:clear --env=test
else
    gosu ${CONTAINER_USER} php bin/console assets:install --env=${APP_ENVIRONMENT}
fi

# add all docker networks to RemoteIPInternalProxy (needed for REMOTE_ADDR behind reverse proxy & logging)
#ip -h -o address | grep eth | awk '{ print $4 }' > /etc/apache2/conf-available/trusted-docker-proxies.conf

apache2-foreground -DFOREGROUND
