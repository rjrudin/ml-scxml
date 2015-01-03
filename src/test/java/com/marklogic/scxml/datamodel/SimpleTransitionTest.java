package com.marklogic.scxml.datamodel;

import org.junit.Ignore;
import org.junit.Test;

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
    @Ignore("TODO")
    public void invalidTransition() {

    }
}
