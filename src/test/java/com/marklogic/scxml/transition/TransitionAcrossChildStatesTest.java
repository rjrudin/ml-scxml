package com.marklogic.scxml.transition;

import org.junit.Test;

import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class TransitionAcrossChildStatesTest extends AbstractScxmlTest {

    private Instance instance;

    @Test
    public void test() {
        String instanceId = startMachineWithId("spec-3.1.5");

        instance = loadInstance(instanceId);
        instance.assertActiveStates("S", "s1", "s11");
        instance.prettyPrint();
        assertMessageExists(1, "entering S");

        fireEvent(instanceId, "e");

        instance = loadInstance(instanceId);
        instance.assertActiveStates("S", "s2", "s21");
        instance.assertTransitionExists(2, "e", "s1", "s2");
        instance.assertTransitionExists(2, "e", "s1", "s21");
        assertMessageExists(2, "leaving s11");
        assertMessageExists(3, "leaving s1");
        assertMessageExists(4, "executing e transition");
        assertMessageExists(5, "entering s2");
        assertMessageExists(6, "entering s21");

        fireEvent(instanceId, "e2");

        instance = loadInstance(instanceId);
        instance.assertActiveStates("finalState");
        instance.assertTransitionExists(3, "e2", "s21", "finalState");
        assertMessageExists(7, "leaving S");
        assertMessageExists(8, "executing e2 transition");
        assertMessageExists(9, "entering finalState");
        // instance.prettyPrint();
    }

    private void assertMessageExists(int position, String message) {
        instance.assertElementExists(format("/mlsc:instance/message[%d][. = '%s']", position, message));
    }
}
