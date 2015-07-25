package com.marklogic.scxml.parallel;

import org.junit.Test;

import com.jayway.restassured.response.Response;
import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

/**
 * This demonstrates the parallel example in 3.1.3 at http://www.w3.org/TR/scxml/#CoreIntroduction .
 */
public class ParallelSampleFromSpecTest extends AbstractScxmlTest {

    private Instance instance;

    @Test
    public void test() {
        String instanceId = startMachineWithId("parallel-sample-from-spec");

        instance = loadInstance(instanceId);
        instance.assertCurrentStates("first");
        instance.assertTransitionExists(1, "first");

        /**
         * Per the spec, when we enter into S12, which is a child of S1, we should also enter into the initial child
         * state of S2, which is S21.
         */
        String event = "e";
        Response r = fireEvent(instanceId, event);
        assertResponseHasInstanceIdAndState(r, instanceId, "S12", "S21");
        instance = loadInstance(instanceId);
        instance.assertCurrentStates("p", "S1", "S12", "S2", "S21");
        instance.assertTransitionExists(2, event, "first", "p");
        instance.assertTransitionExists(2, event, "first", "S1");
        instance.assertTransitionExists(2, event, "first", "S12");
        instance.assertTransitionExists(2, event, "first", "S2");
        instance.assertTransitionExists(2, event, "first", "S21");

        event = "e1";

        fireEvent(instanceId, event);
        instance = loadInstance(instanceId);
        // The instance is still in S1 and S1Final until the whole parallel block completes
        instance.assertCurrentStates("p", "S1", "S1Final", "S2", "S22");
        instance.assertTransitionExists(3, event, "S12", "S1Final");
        instance.assertTransitionExists(4, event, "S21", "S22");

        /**
         * This one is tricky - e2 results in S2 closing. Now S1 and S2 are both closed, which means the parallel state
         * "p" should be closed automatically as well. The "done.start.p" event should thus be fired, which results in a
         * transition from "p" to "finalState".
         */
        event = "e2";

        r = fireEvent(instanceId, event);
        instance = loadInstance(instanceId);
        instance.assertCurrentStates("finalState");
        instance.assertTransitionExists(5, event, "S22", "S2Final");
        instance.assertTransitionExists(6, "done.state.p", "p", "finalState");

        assertMessageExists(1, "leaving S1Final");
        assertMessageExists(2, "leaving S2Final");
        assertMessageExists(3, "leaving S1");
        assertMessageExists(4, "leaving S2");
        assertMessageExists(5, "leaving p");
        assertMessageExists(6, "transitioning to finalState");
        assertMessageExists(7, "entering finalState");
        // instance.prettyPrint();
    }

    private void assertMessageExists(int position, String message) {
        instance.assertElementExists(format("/mlsc:instance/message[%d][. = '%s']", position, message));
    }
}
