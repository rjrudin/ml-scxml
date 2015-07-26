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
        i.assertTransitionExists(1, "a");
        i.assertTransitionExists(2, null, "a", "b");
        i.prettyPrint();

        // fireEvent(id, "t1");
        // i = loadInstance(id);
        // i.assertCurrentStates("d1");
        // i.prettyPrint();
    }
}
