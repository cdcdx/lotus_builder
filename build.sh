#!/bin/bash
set -e
set -o pipefail

cmd=$(basename $0)

ARGS=$(getopt -o a::clht -l all::,clone,config,clear,help,test -n "${cmd}" -- "$@")
eval set -- "${ARGS}"

ROOT_PATH=$(
    cd "$(dirname "$0")"
    pwd
)

SCRIPT_PATH=$ROOT_PATH"/script"
CLONE_AND_CHECKOUT=${SCRIPT_PATH}/clone_and_checkout
LOTUS_GO_MOD=${SCRIPT_PATH}/lotus_go_mod
LOTUS_MAKEFILE=${SCRIPT_PATH}/lotus_makefile
RUST_MOD=${SCRIPT_PATH}/rust_mod
FFI_TEMPLATE=${SCRIPT_PATH}/ffi_template

# http_proxy https_proxy
ENV_LOG_DIR=$(cd `dirname $0`; pwd)
if [ -f $ENV_LOG_DIR/env_proxy ]; then
  source $ENV_LOG_DIR/env_proxy
else
  while [ ! -f $ENV_LOG_DIR/env_proxy ]
  do
    #lotus_proxy
    read -e -p '  please input https_proxy:' lotus_proxy
    #echo ' '
    echo "export http_proxy=$lotus_proxy" >> $ENV_LOG_DIR/env_proxy
    echo "export https_proxy=$lotus_proxy" >> $ENV_LOG_DIR/env_proxy
  done
  echo " "
fi
# tips
if [ -f $ENV_LOG_DIR/env_proxy ]; then
  source $ENV_LOG_DIR/env_proxy
fi
echo -e "\033[34m http_proxy=$http_proxy \033[0m"
echo -e "\033[34m https_proxy=$https_proxy \033[0m"

main() {
    while true; do
        case "${1}" in
        -a | --all)
            echo "builder building..."
            shift
            if [[ -n "${1}" ]]; then
                val_2k="${1}"
                if [ $val_2k = "2k" ]; then
                    all_2k
                elif [ $val_2k = "all" ]; then
                    all_full
                else
                    Usage
                fi
                shift
            else
                all
            fi
            exit 0
            ;;
        --clone)
            echo "builder clone"
            git_clone
            exit 0
            ;;
        -c | --config)
            echo "builder config"
            config
            exit 0
            ;;
        -l | --clear)
            echo "builder clear"
            clear
            exit 0
            ;;
        -t | --test)
            echo "builder test"
            just_for_test
            exit 0
            ;;
        -h | --help)
            Usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            Usage
            exit 0
            ;;
        esac
    done

    Usage
    exit 0
}

Usage() {
    echo "Usage:"${cmd}" options {-a,--all(2k,all) | --clone | -c,--config | -l,--clear | -t,--test | -h}"
}

all() {
    git_clone
    config
    build_lotus
}

all_2k() {
    git_clone
    config
    build_lotus 2k
}

all_full() {
    git_clone
    config
    build_lotus full
}

config() {
    cp -rf $ROOT_PATH/template/* $ROOT_PATH
}

clear() {
    rm -rf lotus
    rm -rf rust-filecoin-proofs-api
    rm -rf rust-fil-proofs
    rm -rf filecoin-ffi
    rm -rf go-state-types
    rm -rf bellman
    rm -rf go-paramfetch
    rm -rf sapling-crypto
    rm -rf specs-actors-v0.9.13
    rm -rf specs-actors-v2.3.2
    rm -rf bellperson

    rm -rf chain-validation
    rm -rf go-fil-markets
    rm -rf go-padreader
    rm -rf specs-storage
    rm -rf statediff
    rm -rf test-vectors
    rm -rf fil-sapling-crypto
    rm -rf chain-validation
    rm -rf neptune
    rm -rf phase2
}

git_clone() {

    # filecash/v1.2.2
    source $CLONE_AND_CHECKOUT "https://github.com/filecash/lotus.git" lotus "93d26195f15dfd452b973609897a72aeb68c310b"
    source $CLONE_AND_CHECKOUT "https://github.com/filecash/filecoin-ffi.git" filecoin-ffi "1d9cb3e8ff53f51f9318fc57e5d00bc79bdc0128"
    source $CLONE_AND_CHECKOUT "https://github.com/filecash/rust-filecoin-proofs-api.git" rust-filecoin-proofs-api "1e2ccacdb4c706a96b11878c67681096e133d30e"
    source $CLONE_AND_CHECKOUT "https://github.com/filecash/rust-fil-proofs.git" rust-fil-proofs "9049e4c9b320a611349b9bb6d3b9287523f9e3d8"
    source $CLONE_AND_CHECKOUT "https://github.com/filecash/specs-actors.git" specs-actors-v0.9.13 "7f44654d2f07d08178f2aa034e5354db49656edf"
    source $CLONE_AND_CHECKOUT "https://github.com/filecash/specs-actors.git" specs-actors-v2.3.2 "e195950ba98adb8ce362030356bf4a3809b7ec77"
    source $CLONE_AND_CHECKOUT "https://github.com/filecash/go-paramfetch.git" go-paramfetch "3e0f0afdc2610811a1ccebea1b2ce31c5a3d121e"
    source $CLONE_AND_CHECKOUT "https://github.com/filecash/go-state-types.git" go-state-types "c8033295a1fc1d6b8f79897993e6de66c571d0d7"
    source $CLONE_AND_CHECKOUT "https://github.com/filecash/bellman.git" bellperson "a96c9a107b8d3d2a05a87011a29c9b373d58332d"

    source $CLONE_AND_CHECKOUT "https://github.com/filecoin-project/go-fil-markets.git" go-fil-markets "v1.0.9"
    source $CLONE_AND_CHECKOUT "https://github.com/filecoin-project/go-padreader.git" go-padreader "ed5fae088b20"
    source $CLONE_AND_CHECKOUT "https://github.com/filecoin-project/specs-storage.git" specs-storage "5188d9774506"
    source $CLONE_AND_CHECKOUT "https://github.com/filecoin-project/test-vectors" test-vectors "d9a75a7873aee0db28b87e3970d2ea16a2f37c6a"
    source $CLONE_AND_CHECKOUT "https://github.com/filecoin-project/neptune.git" neptune "v2.2.0"
    source $CLONE_AND_CHECKOUT "https://github.com/filecoin-project/phase2.git" phase2 "v0.11.0"

}

check_yesorno() {
  unset yesorno
  while [ -z $yesorno ]
  do
    echo " "
    read -e -r -p "Are you sure set FFI_BUILD_FROM_SOURCE? [[Y]es/[N]o " input
    case $input in
      [yY][eE][sS]|[yY])
        echo -e "\033[34m Yes \033[0m"
        yesorno=1
        ;;

      [nN][oO]|[nN])
        echo -e "\033[34m No \033[0m"
        yesorno=0
        ;;

      *)
        echo -e "\033[31m Invalid input... \033[0m"
        ;;
    esac
  done
# return $yesorno
}

build_lotus() {
    cd filecoin-ffi
    make clean
    cd -

    check_yesorno
    if [ $yesorno -eq 1 ]; then
       _FFI_BUILD_FROM_SOURCE=1
    else
       _FFI_BUILD_FROM_SOURCE=0
    fi
    
    set +e
    result=$(grep -m 1 'vendor_id' /proc/cpuinfo | grep "Intel")
    if [[ "$result" != "" ]] ; then
       arch=intel
       export CGO_CFLAGS="-O -D__BLST_PORTABLE__" 
       export RUSTFLAGS="-C target-cpu=native -A dead_code"
    else
       arch=amd
    fi
    set -e
    
    cd lotus
    make clean
    if [ $_FFI_BUILD_FROM_SOURCE -eq 1 ]; then
        FBFS="FFI_BUILD_FROM_SOURCE=1"
    else
        FBFS="FFI_BUILD_FROM_SOURCE=0"
    fi
    BUILD_ENV=${BUILD_ENV}" "$FBFS
    echo make "$@" ${BUILD_ENV}
    make "$@" ${BUILD_ENV}
    cd -
}

main "$@"

