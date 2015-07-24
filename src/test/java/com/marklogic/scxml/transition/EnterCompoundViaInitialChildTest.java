package com.marklogic.scxml.transition;

import org.junit.Test;

import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class EnterCompoundViaInitialChildTest extends AbstractScxmlTest {

    private Instance instance;
    
    @Test
    public void test() {
        String id = startMachineWithId("initial-child");

        instance = loadInstance(id);
        instance.assertCurrentStates("S1", "S1");
        instance.assertTransitionExists(1, "S");
        instance.assertTransitionExists(1, "S1");

        assertMessageExists(1, "entering S");
        assertMessageExists(2, "entering S1");
    }

    private void assertMessageExists(int position, String message) {
        instance.assertElementExists(format("/mlsc:instance/message[%d][. = '%s']", position, message));
    }
}
