package com.marklogic.scxml.transition;

import org.junit.Test;

import com.jayway.restassured.response.Response;
import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class ExecuteTransitionWithConditionTest extends AbstractScxmlTest {

    private Instance i;

    @Test
    public void test() {
        String id = startMachineWithId("conditional-transaction");
        i = loadInstance(id);
        i.assertCurrentStates("b");
        assertInitialTransitionsExist();

        fireEvent(id, "t1");
        i = loadInstance(id);
        i.assertCurrentStates("d1");
        assertT1TransitionsExist();

        fireEvent(id, "t2");
        i = loadInstance(id);
        i.assertCurrentStates("e1");
        assertT2TransitionsExist();

        fireEvent(id, "t3");
        i = loadInstance(id);
        i.assertCurrentStates("f2");
        assertT3TransitionsExist();

        Response r = fireEvent(id, "t4");
        assertResponseHasInstanceIdAndState(r, id, "g3", "h");
        i = loadInstance(id);
        i.assertCurrentStates("g3", "h");
        assertT4TransitionsExist();

        r = fireEvent(id, "t5");
        assertResponseHasInstanceIdAndState(r, id, "i");
        i = loadInstance(id);
        i.assertCurrentStates("g3", "i");
        assertT5TransitionsExist();

        r = fireEvent(id, "t5");
        assertResponseHasInstanceIdAndState(r, id, "last");
        i = loadInstance(id);
        i.assertCurrentStates("last");
        assertSecondT5TransitionExists();
        i.prettyPrint();
    }

    private void assertInitialTransitionsExist() {
        i.assertTransitionExists(1, "a");
        i.assertTransitionExists(2, null, "a", "b");
    }

    private void assertT1TransitionsExist() {
        assertInitialTransitionsExist();
        i.assertTransitionExists(3, "t1", "b", "c");
        i.assertTransitionExists(4, null, "c", "d1");
    }

    private void assertT2TransitionsExist() {
        assertT1TransitionsExist();
        i.assertTransitionExists(5, "t2", "d1", "e1");
    }

    private void assertT3TransitionsExist() {
        assertT2TransitionsExist();
        i.assertTransitionExists(6, "t3", "e1", "f2");
    }

    private void assertT4TransitionsExist() {
        assertT3TransitionsExist();
        i.assertTransitionExists(7, "t4", "f2", "g3");
        /**
         * This transition starts from an initial element that cannot have an ID. So our transition element only
         * captures the enter state.
         */
        i.assertTransitionExists(8, "h");
    }

    private void assertT5TransitionsExist() {
        assertT4TransitionsExist();
        i.assertTransitionExists(9, "t5", "h", "i");
    }

    private void assertSecondT5TransitionExists() {
        assertT5TransitionsExist();
        i.assertTransitionExists(10, "t5", "g3", "last");
        i.assertTransitionExists(10, "t5", "i", "last");
    }
}
