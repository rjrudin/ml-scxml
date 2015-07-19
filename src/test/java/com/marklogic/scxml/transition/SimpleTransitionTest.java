package com.marklogic.scxml.transition;

import org.junit.Test;

import com.jayway.restassured.RestAssured;
import com.jayway.restassured.response.Response;
import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class SimpleTransitionTest extends AbstractScxmlTest {

    @Test
    public void twoSimpleTransitions() {
        final String machineId = "two-simple-transitions";
        String id = startMachineWithId(machineId);

        Instance i = loadInstance(id);
        i.assertMachineId(machineId);
        i.assertInstanceId(id);
        i.assertActiveState("Open");
        i.assertTransitionExists(1, null, "Open");

        fireEvent(id, "Start");
        i = loadInstance(id);
        i.assertActiveState("In Progress");
        i.assertTransitionExists(2, "Open", "In Progress");

        fireEvent(id, "Finish");
        i = loadInstance(id);
        i.assertActiveState("Closed");
        i.assertTransitionExists(2, "Open", "In Progress");
        i.assertTransitionExists(3, "In Progress", "Closed");
    }

    @Test
    public void invalidTransition() {
        final String machineId = "two-simple-transitions";
        String id = startMachineWithId(machineId);

        Response r = RestAssured.post(SERVICE_PATH + "?rs:instanceId=" + id + "&rs:event=Unknown");
        assertEquals(500, r.getStatusCode());
        assertTrue("Expecting a JSON response", r.getContentType().startsWith("application/json"));
        assertTrue(r.asString().contains("Could not find transition for event 'Unknown' (MISSING-TRANSITION)"));
    }
}
