INTEGRATION TESTING
===================

PROJECT STRUCTURE
-----------------

PROJECT_ROOT (maven project)
 - MODULE_1 (maven module)
 - MODULE_2
 - MODULE_3
 - TESTSUITE (all non functional tests, maven module) -Dts (to enable)
    - STRESS (stress tests) -Dts.stress (to enable)
    - BENCHMARK (benchmark tests) -Dts.benchmark (to enable)
    - INTEGRATION (integration tests) -Dts.skip.integration (to skip integration tests)
       - STANDALONE (Standalone/CDI tests) -Dts.skip.integration.standalone (to skip standalone integration tests)
       - STANDALONE_CLUSTER (JSR cluster tests) -Dts.skip.integration.standalone-cluster (to skip standalone cluster integration tests)
       - JEE (JEE related integration tests) -Dts.skip.integration.jee (to skip jee tests)
       - JEE_CLUSTER (Clustered JEE tests) -Dts.skip.integration.jee-cluster (to skip jee cluster tests)
       - pom.xml (multi-profile) 
    - pom.xml (multi-profile)
 - pom.xml (multi profile, with and without integration tests)

to enable testsuite tests run
 $mvn -Dts ... 
in this scenario integration tests will run by default to skip them run 
 $mvn -Dts -Dts.skip.integration
 
to skip tests located in integration test submodule run:
 $mvn -Dts -Dts.skip.integration.<module_name>

for example module_name = jee-cluster

to enable stress tests run
 $mvn -Dts -Dts.stress
 

format of java packages located in integration module: com.ericsson.oss.itpf.sdk.integration.<module_name>
for example: 
 com.ericsson.oss.itpf.sdk.integration.skd-config-core.*
 

NOTE: Functional tests are located in MODULE_X/src/test folder
 