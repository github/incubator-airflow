#!/usr/bin/env bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

#
# Asserts that you are actually in container
#
function assert_in_container() {
    if [[ ! -f /.dockerenv ]]; then
        echo >&2
        echo >&2 "You are not inside the Airflow docker container!"
        echo >&2 "You should only run this script in the Airflow docker container as it may override your files."
        echo >&2 "Learn more about how we develop and test airflow in:"
        echo >&2 "https://github.com/apache/airflow/blob/master/CONTRIBUTING.rst"
        echo >&2
        exit 1
    fi
}

function in_container_script_start() {
    if [[ ${AIRFLOW_CI_VERBOSE:="false"} == "true" ]]; then
        set -x
    fi
}

function in_container_script_end() {
    if [[ ${AIRFLOW_CI_VERBOSE:="false"} == "true" ]]; then
        set +x
    fi
}

function print_in_container_info() {
    if [[ ${AIRFLOW_CI_SILENT:="false"} != "true" ]]; then
        echo "$@"
    fi
}

#
# Cleans up PYC files (in case they come in mounted folders)
#
function in_container_cleanup_pyc() {
    print_in_container_info
    print_in_container_info "Cleaning up .pyc files"
    print_in_container_info
    set +o pipefail
    NUM_FILES=$(sudo find . \
        -path "./airflow/www/node_modules" -prune -o \
        -path "./airflow/www_rbac/node_modules" -prune -o \
        -path "./.eggs" -prune -o \
        -path "./docs/_build" -prune -o \
        -path "./build" -prune -o \
        -name "*.pyc" | grep ".pyc$" | sudo xargs rm -vf | wc -l)
    print_in_container_info "Number of deleted .pyc files: ${NUM_FILES}"
    set -o pipefail
    print_in_container_info
    print_in_container_info
}

#
# Cleans up __pycache__ directories (in case they come in mounted folders)
#
function in_container_cleanup_pycache() {
    print_in_container_info
    print_in_container_info "Cleaning up __pycache__ directories"
    print_in_container_info
    set +o pipefail
    NUM_FILES=$(find . \
        -path "./airflow/www/node_modules" -prune -o \
        -path "./airflow/www_rbac/node_modules" -prune -o \
        -path "./.eggs" -prune -o \
        -path "./docs/_build" -prune -o \
        -path "./build" -prune -o \
        -name "__pycache__" | grep "__pycache__" | sudo xargs rm -rvf | wc -l)
    print_in_container_info "Number of deleted __pycache__ dirs (and files): ${NUM_FILES}"
    set -o pipefail
    print_in_container_info
    print_in_container_info
}

#
# Fixes ownership of files generated in container - if they are owned by root, they will be owned by
# The host user.
#
function in_container_fix_ownership() {
    print_in_container_info
    print_in_container_info "Changing ownership of root-owned files to ${HOST_USER_ID}.${HOST_GROUP_ID}"
    print_in_container_info
    set +o pipefail
    sudo find . -user root | sudo xargs chown -v "${HOST_USER_ID}.${HOST_GROUP_ID}" | wc -l | \
        xargs -n 1 echo "Number of files with changed ownership:"
    set -o pipefail
    print_in_container_info
    print_in_container_info
}

function in_container_go_to_airflow_sources() {
    pushd "${AIRFLOW_SOURCES}"  &>/dev/null || exit 1
    print_in_container_info
    print_in_container_info "Running in $(pwd)"
    print_in_container_info
}

function in_container_basic_sanity_check() {
    assert_in_container
    in_container_go_to_airflow_sources
    in_container_cleanup_pyc
    in_container_cleanup_pycache
}

export DISABLE_CHECKS_FOR_TESTS="missing-docstring,no-self-use,too-many-public-methods,protected-access"

function start_output_heartbeat() {
    MESSAGE=${1:="Still working!"}
    INTERVAL=${2:=10}
    echo
    echo "Starting output heartbeat"
    echo

    bash 2> /dev/null <<EOF &
while true; do
  echo "\$(date): ${MESSAGE} "
  sleep ${INTERVAL}
done
EOF
    export HEARTBEAT_PID=$!
}

function stop_output_heartbeat() {
    kill "${HEARTBEAT_PID}"
    wait "${HEARTBEAT_PID}" || true 2> /dev/null
}

function setup_kerberos() {
    FQDN=$(hostname)
    ADMIN="admin"
    PASS="airflow"
    KRB5_KTNAME=/etc/airflow.keytab

    sudo cp "${MY_DIR}/krb5/krb5.conf" /etc/krb5.conf

    echo -e "${PASS}\n${PASS}" | \
        sudo kadmin -p "${ADMIN}/admin" -w "${PASS}" -q "addprinc -randkey airflow/${FQDN}" 2>&1 \
          | sudo tee "${AIRFLOW_HOME}/logs/kadmin_1.log" >/dev/null
    RES_1=$?

    sudo kadmin -p "${ADMIN}/admin" -w "${PASS}" -q "ktadd -k ${KRB5_KTNAME} airflow" 2>&1 \
          | sudo tee "${AIRFLOW_HOME}/logs/kadmin_2.log" >/dev/null
    RES_2=$?

    sudo kadmin -p "${ADMIN}/admin" -w "${PASS}" -q "ktadd -k ${KRB5_KTNAME} airflow/${FQDN}" 2>&1 \
          | sudo tee "${AIRFLOW_HOME}/logs``/kadmin_3.log" >/dev/null
    RES_3=$?

    if [[ ${RES_1} != 0 || ${RES_2} != 0 || ${RES_3} != 0 ]]; then
        exit 1
    else
        echo
        echo "Kerberos enabled and working."
        echo
        sudo chmod 0644 "${KRB5_KTNAME}"
    fi
}
