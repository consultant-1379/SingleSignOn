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
package example.ejb.service;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import javax.ejb.Singleton;
import javax.ejb.Startup;
import javax.inject.Inject;

import org.slf4j.Logger;

@Singleton
@Startup
public class MyServiceStartupBean {

    @Inject
    private Logger logger;

    @PostConstruct
    void onServiceStart() {
        this.logger.info("Starting my service");
    }

    @PreDestroy
    void onServiceStop() {
        this.logger.info("Stopping my service");
    }

}
