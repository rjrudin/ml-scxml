package com.marklogic.scxml.datamodel;

import org.junit.Ignore;
import org.junit.Test;

import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class SimpleTransitionTest extends AbstractScxmlTest {

    /**
     * TODO We'll want to capture the current user at some point. Should have an extension point for building a
     * transition.
     */
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
        i.assertElementExists("/mlsc:instance/mlsc:transitions/mlsc:transition"
                + "[mlsc:from/@state = 'Open' and mlsc:to/@state = 'In Progress' and @date-time != '']");
        i.prettyPrint();
    }

    @Test
    @Ignore("TODO")
    public void invalidTransition() {

    }
}
