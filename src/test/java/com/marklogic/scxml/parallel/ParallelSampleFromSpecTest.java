package com.marklogic.scxml.parallel;

import org.junit.Test;

import com.jayway.restassured.RestAssured;
import com.jayway.restassured.response.Response;
import com.marklogic.junit.Fragment;
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
        i = loadInstance(instanceId);
        i.assertActiveStates("S12", "S21");
        i.assertTransitionExists(2, "first", "S12");
        i.assertTransitionExists(2, "first", "S21");

        // Fire event "e1"
        // TODO The term "active states" is misleading because S1Final is a final state
        fireEvent(instanceId, "e1");
        i = loadInstance(instanceId);
        i.assertActiveStates("S1Final", "S22");
        i.assertTransitionExists(3, "S12", "S1Final");
        i.assertTransitionExists(4, "S21", "S22");

        // As state S1 finished, we expect an event courtesy of the test implementation
        String xml = RestAssured.get(format("/v1/documents?uri=/ml-scxml/event/%s/done.state.S1Final.xml", instanceId))
                .asString();
        Fragment f = parse(xml);
        f.assertElementExists("/mlsc:test-event[. = 'done.state.S1Final']");
        
        // Fire event "e2"
        r = fireEvent(instanceId, "e2");
        i = loadInstance(instanceId);
        //i.assertActiveStates("final");
    }
}
