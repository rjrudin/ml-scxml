package com.marklogic.scxml.datamodel;

import org.junit.Test;

import com.jayway.restassured.path.json.JsonPath;
import com.jayway.restassured.response.Response;
import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class AssignTest extends AbstractScxmlTest {

    @Test
    public void executeAssignmentOnStateEntry() {
        String instanceId = startMachineWithId("assign");

        Instance i = loadInstance(instanceId);
        i.assertMachineId("assign");
        i.assertInstanceId(instanceId);
        i.assertState("first");
        i.assertDatamodelElementExists("ticket", "price[. = '0']");

        Response r = triggerEvent(instanceId, "e");
        JsonPath json = r.jsonPath();
        assertEquals(instanceId, json.getString("instanceId"));
        assertEquals("s1", json.getString("state"));

        i = loadInstance(instanceId);
        i.assertState("s1");
        i.assertDatamodelElementExists("ticket", "price[. = '10']");
        i.prettyPrint();
    }
}
