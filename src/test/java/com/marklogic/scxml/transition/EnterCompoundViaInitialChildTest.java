package com.marklogic.scxml.transition;

import org.junit.Test;

import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class EnterCompoundViaInitialChildTest extends AbstractScxmlTest {

    /**
     * Verifies that an initial element must have a transition to take it to another state.
     */
    @Test
    public void test() {
        String id = startMachineWithId("initial-child");

        Instance i = loadInstance(id);
        i.assertCurrentStates("S", "S1");
        i.assertTransitionExists(1, "S");
        i.assertTransitionExists(2, "S1");

        i.assertTestMessageExists(1, "entering S");
        i.assertTestMessageExists(2, "entering initial state");
        i.assertTestMessageExists(3, "entering S1");
    }
}
