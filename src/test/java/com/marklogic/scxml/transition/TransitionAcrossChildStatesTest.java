package com.marklogic.scxml.transition;

import org.junit.Test;

import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class TransitionAcrossChildStatesTest extends AbstractScxmlTest {

    @Test
    public void test() {
        String instanceId = startMachineWithId("spec-3.1.5");

        Instance i = loadInstance(instanceId);
        i.assertActiveStates("S", "s1", "s11");

        /**
         * The "e" transition is on state s1. s11 doesn't have any transitions, but we still leave it because we're
         * existing s1, which means we also need to fire its s11's onExit block.
         */
        fireEvent(instanceId, "e");

        i = loadInstance(instanceId);
        i.assertActiveStates("S", "s2", "s21");
        i.assertTransitionExists(2, "e", "s1", "s2");
        i.assertTransitionExists(2, "e", "s1", "s21");
        
        i.prettyPrint();
    }
}
