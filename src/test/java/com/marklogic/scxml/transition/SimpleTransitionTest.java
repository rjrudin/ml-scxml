package com.marklogic.scxml.transition;

import org.junit.Test;

import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class SimpleTransitionTest extends AbstractScxmlTest {

    /**
     * Just making sure we can go from Open to In Progress to Closed.
     */
    @Test
    public void twoSimpleTransitions() {
        final String machineId = "two-simple-transitions";
        String id = startMachineWithId(machineId);

        Instance i = loadInstance(id);
        i.assertMachineId(machineId);
        i.assertInstanceId(id);
        i.assertActiveState("Open");
        i.assertTransitionExists(1, "Open");

        fireEvent(id, "Start");
        i = loadInstance(id);
        i.assertActiveState("In Progress");
        i.assertTransitionExists(2, "Start", "Open", "In Progress");

        fireEvent(id, "Finish");
        i = loadInstance(id);
        i.assertActiveState("Closed");
        i.assertTransitionExists(2, "Start", "Open", "In Progress");
        i.assertTransitionExists(3, "Finish", "In Progress", "Closed");
    }

    /**
     * According to the spec, when an event doesn't match any transitions for the current state(s) of the instance, the
     * event is just discarded.
     */
    @Test
    public void invalidEvent() {
        final String machineId = "two-simple-transitions";
        String id = startMachineWithId(machineId);

        fireEvent(id, "Unknown");

        Instance i = loadInstance(id);
        i.assertActiveState("Open");
        i.assertTransitionExists(1, "Open");
        i.assertTransitionCount("Should just have the one transition from when the instance started", 1);
    }
}
