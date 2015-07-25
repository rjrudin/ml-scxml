package com.marklogic.scxml.execcontent;

import org.junit.Test;

import com.jayway.restassured.response.Response;
import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class ExecuteRaiseOnEntryTest extends AbstractScxmlTest {

    @Test
    public void test() {
        String id = startMachineWithId("raise-simple");
        Instance i = loadInstance(id);
        i.assertCurrentStates("Open");

        Response r = fireEvent(id, "Start");
        assertResponseHasInstanceIdAndState(r, id, "Closed");

        i = loadInstance(id);
        i.assertCurrentStates("Closed");
        i.assertTransitionExists(1, "Open");
        i.assertTransitionExists(2, "Start", "Open", "In Progress");
        i.assertTransitionExists(3, "e1", "In Progress", "Closed");

        i.assertTestMessageExists(1, "about to raise e1");
        i.assertTestMessageExists(2, "just raised e1");
        i.assertTestMessageExists(3, "executing e1 transition");
    }
}
