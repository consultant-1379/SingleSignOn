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

import javax.enterprise.event.Observes;
import javax.inject.Inject;
import javax.inject.Singleton;

import org.slf4j.Logger;

import com.ericsson.oss.itpf.sdk.config.annotation.ConfigurationChangeNotification;
import com.ericsson.oss.itpf.sdk.config.annotation.Configured;

@Singleton
public class ConfigurationBean {
	
	@Inject
	private Logger logger;

	@Inject
	/*
	 *  com.ericsson.oss.itpf.sdk.config.annotation.Configured
	 */
	@Configured(propertyName = "testNumber")
	private Integer integerValue;

	void listenForChanges(@Observes @ConfigurationChangeNotification(propertyName="testNumber") Integer value) {
		this.logger.info("Received notification that value changed to {}", value);
		this.integerValue = value;
	}

	/**
	 * @return the integerValue
	 */
	public Integer getIntegerValue() {
		return this.integerValue;
	}

}
