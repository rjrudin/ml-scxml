package com.marklogic.scxml.transition;

import org.junit.Test;

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

        fireEvent(id, "t4");
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
}
