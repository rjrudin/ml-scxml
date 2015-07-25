package com.marklogic.scxml.execcontent;

import org.junit.Before;
import org.junit.Test;

import com.jayway.restassured.response.Response;
import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class ExecuteAssignOnEntryTest extends AbstractScxmlTest {

    private String instanceId;

    @Before
    public void setup() {
        instanceId = startMachineWithId("assign");

        Instance i = loadInstance(instanceId);
        i.assertMachineId("assign");
        i.assertInstanceId(instanceId);
        i.assertCurrentState("first");
        i.assertDatamodelElementExists("ticket", "price[. = '0']");
    }

    @Test
    public void executeS1AssignmentOnEntry() {
        Response r = fireEvent(instanceId, "e");
        assertResponseHasInstanceIdAndState(r, instanceId, "s1");
        assertStateAndPrices("s1", "10", "0", "0");
    }

    @Test
    public void executeS2AssignmentOnEntry() {
        Response r = fireEvent(instanceId, "e2");
        assertResponseHasInstanceIdAndState(r, instanceId, "s2");
        assertStateAndPrices("s2", "0", "20", "0");
    }

    @Test
    public void executeS3AssignmentOnEntry() {
        Response r = fireEvent(instanceId, "anyEvent");
        assertResponseHasInstanceIdAndState(r, instanceId, "s3");
        assertStateAndPrices("s3", "0", "0", "30");
    }

    private void assertStateAndPrices(String state, String price1, String price2, String price3) {
        Instance i = loadInstance(instanceId);
        i.assertCurrentState(state);
        i.assertDatamodelElementExists("ticket", format("price[. = '%s']", price1));
        i.assertDatamodelElementExists("secondTicket", format("price[. = '%s']", price2));
        i.assertDatamodelElementExists("thirdTicket", format("price[. = '%s']", price3));

        // Verify that our other elements weren't mistakenly dropped
        i.assertDatamodelElementExists("ticket", "otherElement");
        i.assertDatamodelElementExists("secondTicket", "otherElement");
        i.assertDatamodelElementExists("thirdTicket", "otherElement");
    }
}
