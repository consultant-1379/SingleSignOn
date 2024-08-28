package test;

import javax.inject.Inject;

import junit.framework.Assert;

import org.jboss.arquillian.container.test.api.Deployment;
import org.jboss.arquillian.junit.Arquillian;
import org.jboss.shrinkwrap.api.Archive;
import org.jboss.shrinkwrap.api.ShrinkWrap;
import org.jboss.shrinkwrap.api.spec.JavaArchive;
import org.junit.Test;
import org.junit.runner.RunWith;

import example.impl.ServiceStatisticsBean;

@RunWith(Arquillian.class)
public class ServiceStatisticsBeanTest {

    @Inject
    private ServiceStatisticsBean bean;

    @Deployment
    public static Archive<?> createTestArchive() {
	return ShrinkWrap.create(JavaArchive.class, "service-statistics-archive.jar")
		.addAsResource("META-INF/beans.xml", "META-INF/beans.xml").addClass(ServiceStatisticsBean.class);
    }

    @Test
    public void test() {
	Assert.assertNotNull("Resolver should not be null", this.bean);
    }

}
