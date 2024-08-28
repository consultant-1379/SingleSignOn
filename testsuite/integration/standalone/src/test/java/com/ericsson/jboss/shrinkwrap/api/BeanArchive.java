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

package com.ericsson.jboss.shrinkwrap.api;

import org.jboss.shrinkwrap.api.spec.JavaArchive;

/**
 * A CDI specific extension to Shrinkwrap to ease Weld testing.
 * 
 * @author emaomic
 *
 */
public interface BeanArchive extends JavaArchive {
    /**
     * Adds Decorators to the beans.xml.
     *
     * @param classes
     * @return
     */
    BeanArchive decorate(Class<?>... classes);

    /**
     * Adds Interceptors to the beans.xml.
     *
     * @param classes
     * @return
     */
    BeanArchive intercept(Class<?>... classes);

    /**
     * Adds Alternatives to the beans.xml.
     *
     * @param classes
     * @return
     */
    BeanArchive alternate(Class<?>... classes);

    /**
     * Adds a Stereotype Alternative to beans.xml.
     *
     * @param classes
     * @return
     */
    BeanArchive stereotype(Class<?>... classes);
}
