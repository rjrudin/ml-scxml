package com.marklogic.scxml.parallel;

import org.junit.Test;

import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class ParallelSampleFromSpecTest extends AbstractScxmlTest {

    @Test
    public void test() {
        String instanceId = startMachineWithId("parallel-sample-from-spec");

        triggerEvent(instanceId, "e");

        Instance i = loadInstance(instanceId);
        i.assertActiveStates("S12", "S21");
        i.assertTransitionExists("first", "S12");
        i.assertTransitionExists("first", "S21");
    }
}
