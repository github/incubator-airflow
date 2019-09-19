<!--
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
-->

# Apache Airflow

This is a fork of [Airflow 1.10.3](https://github.com/apache/airflow/tree/1.10.3)

## Changes in our fork

- Fix scheduler bug that only allowed running 1 task at a time per DAG due to wrong batch commit
- Hide `Delete` and `Trigger Dag` buttons from the DAG UI
- Hide `Delete` button from the main Airflow page
- Fix `bail.` button onclick action to redirect correctly to the DAG page
- Fix `Mark Success` & `Mark Failed` functionality, it was not using the right `Future`, `Past`, `Downstream` & `Upstream` toggles.
- Cherry pick changes to fix pagination when `showPaused=True` and `hide_paused_dags_by_default=True` https://github.com/apache/airflow/pull/6100
