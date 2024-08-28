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

import javax.enterprise.context.ApplicationScoped;

import com.ericsson.oss.itpf.sdk.instrument.annotation.InstrumentedBean;

@ApplicationScoped
@InstrumentedBean
public class ServiceStatisticsBean {

    private int numberOfRequests;

    /**
     * @return the numberOfRequests
     */
    public int getNumberOfRequests() {
        return this.numberOfRequests;
    }

    /**
     * @param numberOfRequests
     *            the numberOfRequests to set
     */
    public void setNumberOfRequests(final int numberOfRequests) {
        this.numberOfRequests = numberOfRequests;
    }

}
