package com.marklogic.scxml.transition;

import org.junit.Test;

import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class ExecuteTransitionWithConditionTest extends AbstractScxmlTest {

    @Test
    public void test() {
        String id = startMachineWithId("conditional-transaction");
        Instance i = loadInstance(id);
        i.assertCurrentStates("b");

        // fireEvent(id, "t2");
        // i.assertCurrentStates("e1");
        //
        // fireEvent(id, "t3");
        // i.assertCurrentStates("f2");
    }
}
