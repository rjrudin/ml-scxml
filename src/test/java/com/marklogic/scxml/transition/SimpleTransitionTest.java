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
        i.assertState("Open");

        triggerEvent(id, "Start");
        i = loadInstance(id);
        i.assertState("In Progress");
        i.assertTransitionExists("Open", "In Progress");

        triggerEvent(id, "Finish");
        i = loadInstance(id);
        i.assertState("Closed");
        i.assertTransitionExists("Open", "In Progress");
        i.assertTransitionExists("In Progress", "Closed");
        i.prettyPrint();
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
