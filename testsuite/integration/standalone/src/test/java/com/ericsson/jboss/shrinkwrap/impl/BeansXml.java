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

package com.ericsson.jboss.shrinkwrap.impl;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.*;

import org.jboss.shrinkwrap.api.asset.Asset;

class BeansXml implements Asset {
    private final List<Class<?>> alternatives = new ArrayList<Class<?>>();
    private final List<Class<?>> interceptors = new ArrayList<Class<?>>();
    private final List<Class<?>> decorators = new ArrayList<Class<?>>();
    private final List<Class<?>> stereotypes = new ArrayList<Class<?>>();

    BeansXml() {

    }

    public BeansXml alternatives(final Class<?>... alternatives) {
        this.alternatives.addAll(Arrays.asList(alternatives));
        return this;
    }

    public BeansXml interceptors(final Class<?>... interceptors) {
        this.interceptors.addAll(Arrays.asList(interceptors));
        return this;
    }

    public BeansXml decorators(final Class<?>... decorators) {
        this.decorators.addAll(Arrays.asList(decorators));
        return this;
    }

    public BeansXml stereotype(final Class<?>... stereotypes) {
        this.stereotypes.addAll(Arrays.asList(stereotypes));
        return this;
    }

    @Override
    public InputStream openStream() {
        final StringBuilder xml = new StringBuilder();
        xml.append("<beans>\n");
        appendAlternatives(alternatives, stereotypes, xml);
        appendSection("interceptors", "class", interceptors, xml);
        appendSection("decorators", "class", decorators, xml);
        xml.append("</beans>");

        return new ByteArrayInputStream(xml.toString().getBytes());
    }

    private void appendAlternatives(final List<Class<?>> alternatives, final List<Class<?>> stereotypes, final StringBuilder xml) {
        if (alternatives.size() > 0 || stereotypes.size() > 0) {
            xml.append("<").append("alternatives").append(">\n");
            appendClasses("class", alternatives, xml);
            appendClasses("stereotype", stereotypes, xml);
            xml.append("</").append("alternatives").append(">\n");
        }
    }

    private void appendSection(final String name, final String subName, final List<Class<?>> classes, final StringBuilder xml) {
        if (classes.size() > 0) {
            xml.append("<").append(name).append(">\n");
            appendClasses(subName, classes, xml);
            xml.append("</").append(name).append(">\n");
        }
    }

    private void appendClasses(final String name, final List<Class<?>> classes, final StringBuilder xml) {
        for (final Class<?> clazz : classes) {
            xml.append("<").append(name).append(">").append(clazz.getName()).append("</").append(name).append(">\n");
        }
    }
}