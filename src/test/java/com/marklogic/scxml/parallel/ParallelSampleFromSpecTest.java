package com.marklogic.scxml.parallel;

import org.junit.Test;

import com.jayway.restassured.response.Response;
import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class ParallelSampleFromSpecTest extends AbstractScxmlTest {

    /**
     * TODO Test for events being raised.
     */
    @Test
    public void test() {
        // Start the machine up
        String instanceId = startMachineWithId("parallel-sample-from-spec");
        Instance i = loadInstance(instanceId);
        i.assertActiveStates("first");
        i.assertTransitionExists(1, null, "first");

        // Fire event "e"
        Response r = fireEvent(instanceId, "e");
        assertResponseHasInstanceIdAndState(r, instanceId, "S12", "S21");
        Instance i2 = loadInstance(instanceId);
        i2.assertActiveStates("S12", "S21");
        i2.assertTransitionExists(2, "first", "S12");
        i2.assertTransitionExists(2, "first", "S21");

        // Fire event "e1"
        /**
         * I'm not sure how to handle this. S1Final is a final state, but it seems to me that we'd want to track each
         * state that the statechart is currently "in". So the term "active states" may be misleading, but just calling
         * them "states" doesn't seem great either.
         */
        fireEvent(instanceId, "e1");
        Instance i3 = loadInstance(instanceId);
        i3.assertActiveStates("S1Final", "S22");
        i3.assertTransitionExists(3, "S12", "S1Final");
        i3.assertTransitionExists(4, "S21", "S22");
    }
}
