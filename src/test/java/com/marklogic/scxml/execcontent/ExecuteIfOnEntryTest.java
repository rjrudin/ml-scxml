package com.marklogic.scxml.execcontent;

import org.junit.Test;

import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class ExecuteIfOnEntryTest extends AbstractScxmlTest {

    @Test
    public void ifOnEntry() {
        String id = startMachineWithId("if-simple");
        Instance i = loadInstance(id);
        i.assertDatamodelElementExists("ticket", "price[. = '10']");
    }
}
