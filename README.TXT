+----------------------------+
WHERE TO PUT THINGS?
+----------------------------+

api
================================

All remote interfaces and POJOs used by other services. This is the place where to declare dependency on all APIs available in SDK.
All modeled artifacts must go here (channels, events, cache regions, configuration parameters).
This module must not depend on any SDK implementations.

This is the module other services will depend on (compile time) when using your service.
Anything found in this module will be considered part of your interface and you will have to maintain backward compatibility.



jar
================================

CDI (non-JEE) implementation. Might be used when testing JSE environment. Should not use anything not available in CDI environment
(JEE things, for example).
This module must not depend on any SDK implementations.




ejb
================================

JEE wrapper around (mostly for remoting and transaction management) around jar module.
This module must not depend on any SDK implementations.
Should contain only EJBs (SLSB, SFSB, Singletons).




war
================================

All web implementation artifacts: Restful services, Servlets, JSPs etc
This module must not depend on any SDK implementations.




ear
================================

Responsible for packaging whole project. This is the place where to declare dependency on different SDK implementations.
Please note that there are two profiles in this module. 'devel_env' is for packaging implementation modules that are not
production ready (like sdk-config-impl-dev). 'production_env' is for packaging implementation modules that are LITP specific
and can not run on development machines (without LITP installed).

+----------------------------+
BUILDING
+----------------------------+

- By default build is for devel-environment (no LITP specific implementation modules)
- For production environment you should do a build with activated 'production' profile (mvn clean install -P production_env)
(Please check pom.xml in /EAR/ submodule



+----------------------------+
DEPLOYING TO JBOSS
+----------------------------+

System property JBOSS_HOME should point to the installation folder of JBoss (EAP6 - not community version).

Once you started JBoss you have to execute mvn jboss-as:deploy to deploy service