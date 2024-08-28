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
package example.impl;

import java.util.concurrent.atomic.AtomicInteger;

import javax.enterprise.context.ApplicationScoped;
import javax.enterprise.event.Observes;
import javax.inject.Inject;

import org.slf4j.Logger;

import com.ericsson.oss.itpf.sdk.eventbus.model.annotation.Modeled;

import example.api.ServiceModeledEvent;

@ApplicationScoped
public class MyServiceMessageReceiver {

    @Inject
    private Logger logger;

    private final AtomicInteger counter = new AtomicInteger(0);

    void listenForMyOwnMessages(@Observes @Modeled final ServiceModeledEvent modeledEvent) {
        final int received = this.counter.incrementAndGet();
        this.logger.debug("Received {}. In total {} events received", modeledEvent, received);
    }

}
