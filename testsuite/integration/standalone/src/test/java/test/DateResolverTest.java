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

import example.impl.DateResolver;

@RunWith(Arquillian.class)
public class DateResolverTest {

	@Inject
	private DateResolver resolver;
	
	@Deployment
	public static Archive<?> createTestArchive() {
      return ShrinkWrap.create(JavaArchive.class, "resolver-archive.jar").
    		  addAsResource("META-INF/beans.xml", "META-INF/beans.xml").
    		  addClass(DateResolver.class);
	} 
	
	@Test
	public void test() {
		Assert.assertNotNull("Resolver should not be null", this.resolver);
		Assert.assertNotNull("Resolved date should not be null", this.resolver.resolveCurrentDate());
	}

}
