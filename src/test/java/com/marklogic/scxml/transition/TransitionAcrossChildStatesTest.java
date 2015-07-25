package com.marklogic.scxml.transition;

import org.junit.Test;

import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class TransitionAcrossChildStatesTest extends AbstractScxmlTest {

    @Test
    public void test() {
        String instanceId = startMachineWithId("spec-3.1.5");

        Instance i = loadInstance(instanceId);
        i.assertCurrentStates("S", "s1", "s11");
        i.assertTestMessageExists(1, "entering S");

        fireEvent(instanceId, "e");

        i = loadInstance(instanceId);
        i.assertCurrentStates("S", "s2", "s21");
        i.assertTransitionExists(2, "e", "s1", "s2");
        i.assertTransitionExists(2, "e", "s1", "s21");
        i.assertTestMessageExists(2, "leaving s11");
        i.assertTestMessageExists(3, "leaving s1");
        i.assertTestMessageExists(4, "executing e transition");
        i.assertTestMessageExists(5, "entering s2");
        i.assertTestMessageExists(6, "entering s21");

        fireEvent(instanceId, "e2");

        i = loadInstance(instanceId);
        i.assertCurrentStates("finalState");
        i.assertTransitionExists(3, "e2", "s21", "finalState");
        i.assertTestMessageExists(7, "leaving S");
        i.assertTestMessageExists(8, "executing e2 transition");
        i.assertTestMessageExists(9, "entering finalState");
        // instance.prettyPrint();
    }
}
