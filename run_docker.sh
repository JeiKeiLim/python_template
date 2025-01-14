#!/bin/bash
#
# Docker build image, run container, execute last container.
#
# - Author: Jongkuk Lim
# - Contact: limjk@jmarple.ai

xhost +

ORG=jmarpledev

PRJ_NAME=${PWD##*/}
PRJ_NAME="$(tr [A-Z] [a-z] <<< "$PRJ_NAME")"

DOCKER_TAG=$ORG/$PRJ_NAME

CMD_ARGS=( ${@} )
CMD_ARGS=${CMD_ARGS[*]:1}

RUN_SHELL=/usr/bin/zsh

if [[ $2 == :* ]]; then
    DOCKER_TAG=$DOCKER_TAG$2
    CMD_ARGS=${CMD_ARGS[*]:2}
elif [ "$2" = "bash" ]; then
    RUN_SHELL=/bin/bash
 $RUN_SHELL   CMD_ARGS=${CMD_ARGS[*]:2}
fi

if [ "$ARCH" = "aarch64" ]; then
    DOCKER_FILE=./docker/Dockerfile.aarch64
else
    DOCKER_FILE=./docker/Dockerfile
fi

if [ "$1" = "build" ]; then
    if [ "$RUN_SHELL" = "/bin/bash" ]; then
        CMD_ARGS="$CMD_ARGS --build-arg USE_ZSH=false"
    fi
    echo "Building a docker image with tagname $DOCKER_TAG and arguments $CMD_ARGS"
    docker build . -t $DOCKER_TAG -f $DOCKER_FILE $CMD_ARGS --build-arg UID=`id -u` --build-arg GID=`id -g`
elif [ "$1" = "run" ]; then
    if test -f "$HOME/.gitconfig"; then
        CMD_ARGS="$CMD_ARGS -v $HOME/.gitconfig:/home/user/.gitconfig"
    fi
    echo "Run a docker image with tagname $DOCKER_TAG and arguments $CMD_ARGS"

    docker run -tid --privileged --gpus all \
        -e DISPLAY=${DISPLAY} \
        -e TERM=xterm-256color \
        -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
        -v /dev:/dev \
        -v $PWD:/home/user/$PRJ_NAME \
        --network host \
        $CMD_ARGS \
        $DOCKER_TAG $RUN_SHELL

    last_cont_id=$(docker ps -qn 1)
    echo $(docker ps -qn 1) > $PWD/.last_exec_cont_id.txt

    docker exec -ti $last_cont_id $RUN_SHELL
elif [ "$1" = "exec" ]; then
    echo "Execute the last docker container"

    last_cont_id=$(tail -1 $PWD/.last_exec_cont_id.txt)
    docker start ${last_cont_id}
    docker exec -ti ${last_cont_id} $RUN_SHELL
elif [ "$1" = "kill" ]; then
    containers=$(docker ps -f "ancestor=$DOCKER_TAG" -q)
    if [ -z $containers ]; then
        echo "No $DOCKER_TAG container has found!"
    else
        echo "Killing ${#containers[@]} containers of $DOCKER_TAG"
        docker kill $containers
    fi
else
    echo ""
    echo "============= $0 [Usages] ============"
    echo "1) $0 build : build docker image"
    echo "      build --no-cache : Build docker image without cache"
    echo "2) $0 run : launch a new docker container"
    echo "3) $0 exec : execute last container launched"
    echo "4) $0 kill : Kill all containers tagged as $DOCKER_TAG"
fi


