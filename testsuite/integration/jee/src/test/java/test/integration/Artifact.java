/*------------------------------------------------------------------------------
 *******************************************************************************
 * COPYRIGHT Ericsson 2012
 *
 * The copyright to the computer program(s) herein is the property of
 * Ericsson Inc. The programs may be used and/or copied only with written
 * permission from Ericsson Inc. or in accordance with the terms and
 * conditions stipulated in the agreement/contract under which the
 * program(s) have been supplied.
 *******************************************************************************
 *----------------------------------------------------------------------------*/

package test.integration;

import org.jboss.shrinkwrap.resolver.api.DependencyResolvers;
import org.jboss.shrinkwrap.resolver.api.maven.MavenDependencyResolver;

/**
 * Maven artifact constants
 * 
 * @author emaomic
 * 
 */
public class Artifact {
    /**
     * 
     */
    public static final String ORG_SLF4J___SLF4J_API_JAR = "org.slf4j:slf4j-api:jar";

    public static final String COM_ERICSSON_OSS_ITPF_SDK___SERVICES_CORE_JAR = "com.ericsson.oss.itpf.sdk:sdk-services-core:jar";

    public static final String COM_ERICSSON_OSS_ITPF_SDK___CONFIG_API_JAR = "com.ericsson.oss.itpf.sdk:sdk-config-api:jar";

    public static final String COM_ERICSSON_OSS_ITPF_SDK___CONFIG_CORE_JAR = "com.ericsson.oss.itpf.sdk:sdk-config-core:jar";

    public static final String COM_ERICSSON_OSS_ITPF_SDK___CONFIG_IMPL_DEV_JAR = "com.ericsson.oss.itpf.sdk:sdk-config-impl-dev:jar";

    /**
     * 
     * @return
     */
    public static MavenDependencyResolver getMavenResolver() {
	return DependencyResolvers.use(MavenDependencyResolver.class).loadMetadataFromPom("pom.xml");
    }
}
