package com.marklogic.scxml.execcontent;

import org.junit.Test;

import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class ExecuteIfElseIfElseTest extends AbstractScxmlTest {

    @Test
    public void test() {
        String id = startMachineWithId("if-simple");

        fireEvent(id, "e1");
        Instance i = loadInstance(id);
        i.assertDatamodelElementExists("ticket", "price[. = '10']");

        fireEvent(id, "e1");
        i = loadInstance(id);
        i.assertDatamodelElementExists("ticket", "price[. = '20']");

        fireEvent(id, "e1");
        i = loadInstance(id);
        i.assertDatamodelElementExists("ticket", "price[. = '30']");

        fireEvent(id, "e1");
        i = loadInstance(id);
        i.assertDatamodelElementExists("ticket", "price[. = '0']");

        i.assertTestMessageExists(1, "setting price to 10");
        i.assertTestMessageExists(2, "setting price to 20");
        i.assertTestMessageExists(3, "setting price to 30");
        i.assertTestMessageExists(4, "setting price to 0");
    }
}
