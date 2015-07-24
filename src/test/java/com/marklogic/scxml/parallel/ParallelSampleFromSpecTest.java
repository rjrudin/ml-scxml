package com.marklogic.scxml.parallel;

import org.junit.Test;

import com.jayway.restassured.response.Response;
import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

/**
 * This demonstrates the parallel example in 3.1.3 at http://www.w3.org/TR/scxml/#CoreIntroduction .
 */
public class ParallelSampleFromSpecTest extends AbstractScxmlTest {

    @Test
    public void test() {
        String instanceId = startMachineWithId("parallel-sample-from-spec");

        Instance i = loadInstance(instanceId);
        i.assertCurrentStates("first");
        i.assertTransitionExists(1, "first");

        /**
         * Per the spec, when we enter into S12, which is a child of S1, we should also enter into the initial child
         * state of S2, which is S21.
         */
        String event = "e";
        Response r = fireEvent(instanceId, event);
        assertResponseHasInstanceIdAndState(r, instanceId, "S12", "S21");
        i = loadInstance(instanceId);
        i.prettyPrint();
        i.assertCurrentStates("p", "S1", "S12", "S2", "S21");
        i.assertTransitionExists(2, event, "first", "p");
        i.assertTransitionExists(2, event, "first", "S1");
        i.assertTransitionExists(2, event, "first", "S12");
        i.assertTransitionExists(2, event, "first", "S2");
        i.assertTransitionExists(2, event, "first", "S21");

        event = "e1";
        if (true)
            return;

        fireEvent(instanceId, event);
        i = loadInstance(instanceId);
        i.assertCurrentStates("p", "S1Final", "S22");
        i.assertTransitionExists(3, event, "S12", "S1Final");
        i.assertTransitionExists(4, event, "S21", "S22");

        /**
         * This one is tricky - e2 results in S2 closing. Now S1 and S2 are both closed, which means the parallel state
         * "p" should be closed automatically as well. The "done.start.p" event should thus be fired, which results in a
         * transition from "p" to "finalState".
         */
        event = "e2";
        r = fireEvent(instanceId, event);
        i = loadInstance(instanceId);
        i.assertCurrentStates("finalState");
        i.assertTransitionExists(5, event, "S22", "S2Final");
        i.assertTransitionExists(6, "done.state.p", "p", "finalState");
    }
}
