package com.marklogic.scxml.parallel;

import org.junit.Ignore;
import org.junit.Test;

import com.marklogic.scxml.AbstractScxmlTest;

@Ignore("Not ready for this yet")
public class MicrowaveTest extends AbstractScxmlTest {

    @Test
    public void test() {
        String instanceId = startMachineWithId("microwave-02");

        loadInstance(instanceId).prettyPrint();
    }
}
