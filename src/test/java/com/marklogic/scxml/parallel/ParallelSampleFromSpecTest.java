package com.marklogic.scxml.parallel;

import org.junit.Test;

import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class ParallelSampleFromSpecTest extends AbstractScxmlTest {

    /**
     * TODO Test for events being raised.
     */
    @Test
    public void test() {
        String instanceId = startMachineWithId("parallel-sample-from-spec");

        triggerEvent(instanceId, "e");

        Instance i = loadInstance(instanceId);
        i.assertActiveStates("S12", "S21");
        i.assertTransitionExists("first", "S12");
        i.assertTransitionExists("first", "S21");
        
        triggerEvent(instanceId, "e1");
        
        i = loadInstance(instanceId);
        // S1 is now at S1Final, but that's a final state, not an active state
        i.assertActiveStates("S22");
        i.prettyPrint();
        
    }
}
