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
package example.api;

import com.ericsson.oss.itpf.sdk.modeling.eventbus.annotation.ModeledAttribute;
import com.ericsson.oss.itpf.sdk.modeling.eventbus.annotation.ModeledEventDefinition;
import com.ericsson.oss.itpf.sdk.modeling.eventbus.channel.annotation.ModeledChannelDefinition;
import com.ericsson.oss.itpf.sdk.modeling.eventbus.channel.annotation.ModeledChannelType;

@ModeledChannelDefinition(channelId = "myModeledChannel", channelType = ModeledChannelType.POINT_TO_POINT, channelURI = "jms:/queue/myService")
@ModeledEventDefinition(defaultChannelId = "myModeledChannel", version = "1.0.0", description = "My service modeled event")
public class ServiceModeledEvent {

    @ModeledAttribute(description = "my event id")
    private String eventId;

    /**
     * @return the eventId
     */
    public String getEventId() {
        return this.eventId;
    }

    /**
     * @param eventId
     *            the eventId to set
     */
    public void setEventId(final String eventId) {
        this.eventId = eventId;
    }

}
